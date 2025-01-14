import Foundation
import GRDB

private let epoch0 = Date(timeIntervalSince1970: 0)

// sourcery: copyBuilder
struct WorksiteRootRecord : Identifiable, Equatable {
    static let worksite = hasOne(WorksiteRecord.self)
    static let worksiteFlags = hasMany(WorksiteFlagRecord.self)
    static let worksiteFormData = hasMany(WorksiteFormDataRecord.self)
    static let worksiteNotes = hasMany(WorksiteNoteRecord.self)
    static let workTypes = hasMany(WorkTypeRecord.self)
    static let worksiteWorkTypeRequests = hasMany(WorkTypeRequestRecord.self)
    static let networkFiles = hasMany(
        NetworkFileRecord.self,
        through: hasMany(WorksiteToNetworkFileRecord.self),
        using: WorksiteToNetworkFileRecord.files
    )
    static let worksiteLocalImages = hasMany(WorksiteLocalImageRecord.self)

    internal static func create(
        syncedAt: Date,
        networkId: Int64,
        incidentId: Int64,
        id: Int64? = nil
    ) -> WorksiteRootRecord {
        WorksiteRootRecord(
            id: id,
            syncUuid: "",
            localModifiedAt: epoch0,
            syncedAt: epoch0,
            localGlobalUuid: "",
            isLocalModified: false,
            syncAttempt: 0,

            networkId: networkId,
            incidentId: incidentId
        )
    }

    var id: Int64?
    let syncUuid: String
    let localModifiedAt: Date
    let syncedAt: Date
    let localGlobalUuid: String
    let isLocalModified: Bool
    let syncAttempt: Int64

    let networkId: Int64
    let incidentId: Int64
}

extension WorksiteRootRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "worksiteRoot"

    fileprivate enum Columns: String, ColumnExpression {
        case id,
             syncUuid,
             localModifiedAt,
             syncedAt,
             localGlobalUuid,
             isLocalModified,
             syncAttempt,
             networkId,
             incidentId
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static func insertOrRollback(
        _ db: Database,
        _ syncedAt: Date,
        _ networkId: Int64,
        _ incidentId: Int64
    ) throws -> Int64 {
        let rootRecord = WorksiteRootRecord.create(
            syncedAt: syncedAt,
            networkId: networkId,
            incidentId: incidentId
        )
        return try rootRecord.insertAndFetch(db, onConflict: .rollback)!.id!
    }

    static func syncUpdate(
        _ db: Database,
        id: Int64,
        expectedLocalModifiedAt: Date,
        syncedAt: Date,
        networkId: Int64,
        incidentId: Int64
    ) throws {
        let record = try WorksiteRootRecord
            .filter(Columns.id == id && Columns.networkId == networkId && Columns.localModifiedAt == expectedLocalModifiedAt)
            .fetchOne(db)
        if record == nil {
            throw GenericError("Worksite has been changed since local modified state was fetched")
        }

        try db.execute(
            sql:
                """
                UPDATE OR ROLLBACK worksiteRoot
                SET syncedAt=:syncedAt,
                    syncAttempt=0,
                    isLocalModified=0,
                    incidentId=:incidentId
                WHERE id=:id AND
                      networkId=:networkId AND
                      localModifiedAt=:expectedLocalModifiedAt
                """,
            arguments: [
                "id": id,
                "expectedLocalModifiedAt": expectedLocalModifiedAt,
                "syncedAt": syncedAt,
                "networkId": networkId,
                "incidentId": incidentId,
            ]
        )
    }

    static func setRootUnmodified(
        _ db: Database,
        _ id: Int64,
        _ syncedAt: Date
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE worksiteRoot
                SET syncedAt=:syncedAt,
                    isLocalModified=0,
                    syncAttempt=0
                WHERE id=:id
                """,
            arguments: [
                "id": id,
                "syncedAt": syncedAt,
            ]
        )
    }

    static func getCount(_ db: Database, _ incidentId: Int64) throws -> Int {
        try WorksiteRootRecord
            .filter(Columns.incidentId == incidentId)
            .fetchCount(db)
    }

    static func getWorksiteId(_ db: Database, _ networkId: Int64) throws -> Int64 {
        let record = try WorksiteRootRecord
            .filter(Columns.networkId == networkId && Columns.localGlobalUuid == "")
            .fetchOne(db)
        return record?.id ?? 0
    }

    static func localModifyUpdate(
        _ db: Database,
        id: Int64,
        incidentId: Int64,
        syncUuid: String,
        localModifiedAt: Date
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE worksiteRoot
                SET incidentId      =:incidentId,
                    syncUuid        =:syncUuid,
                    localModifiedAt =:localModifiedAt,
                    isLocalModified =1
                WHERE id=:id
                """,
            arguments: [
                "id": id,
                "incidentId": incidentId,
                "syncUuid": syncUuid,
                "localModifiedAt": localModifiedAt,
            ]
        )
    }

    static func updateWorksiteNetworkId(
        _ db: Database,
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE worksiteRoot
                SET networkId=:networkId,
                    localGlobalUuid=''
                WHERE id=:id
                """,
            arguments: [
                "id": id,
                "networkId": networkId
            ]
        )
    }
}

extension DerivableRequest<WorksiteRootRecord> {
    func byUnique(
        _ networkId: Int64,
        _ localGlobalUuid: String = ""
    ) -> Self {
        filter(
            RootColumns.networkId == networkId &&
            RootColumns.localGlobalUuid == localGlobalUuid
        )
    }

    func networkIdsIn(_ ids: Set<Int64>) -> Self {
        filter(ids.contains(WorksiteRootRecord.Columns.networkId))
    }

    func orderedByLocalModifiedAtDesc() -> Self {
        order(RootColumns.localModifiedAt.desc)
    }

    func byIncidentId(_ id: Int64) -> Self {
        filter(RootColumns.incidentId == id)
    }

    func selectIdColumn() -> Self {
        select(RootColumns.id)
    }

    func visualColumns() -> Self {
        select(RootColumns.id, RootColumns.isLocalModified)
    }

    func filterLocalModified() -> Self {
        filter(RootColumns.isLocalModified == true)
    }
}

fileprivate typealias RootColumns = WorksiteRootRecord.Columns

extension Database {
    private func updateNetworkId(
        _ tableName: String,
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try execute(
            sql:
                """
                UPDATE \(tableName)
                SET networkId   =:networkId
                WHERE id        =:id
                """,
            arguments: [
                "id": id,
                "networkId": networkId,
            ]
        )
    }

    func updateWorksiteNetworkId(
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try updateNetworkId("worksite", id, networkId)
    }

    fileprivate func updateWorksiteFlagNetworkId(
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try updateNetworkId("worksiteFlag", id, networkId)
    }

    fileprivate func updateWorkTypeNetworkId(
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try updateNetworkId("workType", id, networkId)
    }
}

// sourcery: copyBuilder
struct WorksiteRecord : Identifiable, Equatable {
    static let root = belongsTo(WorksiteRootRecord.self)
    static let recent = hasOne(RecentWorksiteRecord.self)

    var id: Int64?
    let networkId: Int64
    let incidentId: Int64
    let address: String
    let autoContactFrequencyT: String?
    let caseNumber: String
    let caseNumberOrder: Int64
    let city: String
    let county: String
    // This can be null if full data is queried without short
    let createdAt: Date?
    let email: String?
    let favoriteId: Int64?
    let keyWorkTypeType: String
    let keyWorkTypeOrgClaim: Int64?
    let keyWorkTypeStatus: String
    let latitude: Double
    let longitude: Double
    let name: String
    let phone1: String?
    let phone2: String?
    let plusCode: String?
    let postalCode: String
    let reportedBy: Int64?
    let state: String
    let svi: Double?
    let what3Words: String?
    let updatedAt: Date

    // TODO: Write tests throughout (model, data, edit feature)
    /**
     * Is relevant when [WorksiteRootEntity.isLocalModified] otherwise ignore
     */
    let isLocalFavorite: Bool

    private static let endNumbersCapture = #/(?:^|\D)(\d+)(?:\D|$)/#
    static func parseCaseNumberOrder(_ caseNumber: String) -> Int64 {
        if let match = caseNumber.firstMatch(of: endNumbersCapture),
           let parsed = Int64(match.1) {
            return parsed
        }
        return 0
    }
}

extension WorksiteRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "worksite"

    fileprivate enum Columns: String, ColumnExpression {
        case id,
             networkId,
             incidentId,
             address,
             autoContactFrequencyT,
             caseNumber,
             caseNumberOrder,
             city,
             county,
             // This can be null if full data is queried without short
             createdAt,
             email,
             favoriteId,
             keyWorkTypeType,
             keyWorkTypeOrgClaim,
             keyWorkTypeStatus,
             latitude,
             longitude,
             name,
             phone1,
             phone2,
             plusCode,
             postalCode,
             reportedBy,
             state,
             svi,
             what3Words,
             updatedAt,
             isLocalFavorite
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    func syncUpdateWorksite(_ db: Database) throws {
        try db.execute(
            sql:
                """
                UPDATE OR ROLLBACK worksite
                SET
                incidentId          =:incidentId,
                address             =:address,
                autoContactFrequencyT=COALESCE(:autoContactFrequencyT,autoContactFrequencyT),
                caseNumber     	    =:caseNumber,
                caseNumberORder     =:caseNumberOrder,
                city                =:city,
                county              =:county,
                createdAt           =COALESCE(:createdAt, createdAt),
                email               =COALESCE(:email, email),
                favoriteId          =:favoriteId,
                keyWorkTypeType     =CASE WHEN :keyWorkTypeType=='' THEN keyWorkTypeType ELSE :keyWorkTypeType END,
                keyWorkTypeOrgClaim =CASE WHEN :keyWorkTypeOrgClaim<0 THEN keyWorkTypeOrgClaim ELSE :keyWorkTypeOrgClaim END,
                keyWorkTypeStatus   =CASE WHEN :keyWorkTypeStatus=='' THEN keyWorkTypeStatus ELSE :keyWorkTypeStatus END,
                latitude    =:latitude,
                longitude   =:longitude,
                name        =:name,
                phone1      =COALESCE(:phone1, phone1),
                phone2      =COALESCE(:phone2, phone2),
                plusCode    =COALESCE(:plusCode, plusCode),
                postalCode  =:postalCode,
                reportedBy  =COALESCE(:reportedBy, reportedBy),
                state       =:state,
                svi         =:svi,
                what3Words  =COALESCE(:what3Words, what3Words),
                updatedAt   =:updatedAt
                WHERE id=:id AND networkId=:networkId
                """,
            arguments: [
                "id": id,
                "networkId": networkId,
                "incidentId": incidentId,
                "address": address,
                "autoContactFrequencyT": autoContactFrequencyT,
                "caseNumber": caseNumber,
                "caseNumberOrder": caseNumberOrder,
                "city": city,
                "county": county,
                "createdAt": createdAt,
                "email": email,
                "favoriteId": favoriteId,
                "keyWorkTypeType": keyWorkTypeType,
                "keyWorkTypeOrgClaim": keyWorkTypeOrgClaim,
                "keyWorkTypeStatus": keyWorkTypeStatus,
                "latitude": latitude,
                "longitude": longitude,
                "name": name,
                "phone1": phone1,
                "phone2": phone2,
                "plusCode": plusCode,
                "postalCode": postalCode,
                "reportedBy": reportedBy,
                "state": state,
                "svi": svi,
                "what3Words": what3Words,
                "updatedAt": updatedAt,
            ]
        )
    }

    static func syncFillWorksite(
        _ db: Database,
        _ id: Int64,
        autoContactFrequencyT: String?,
        caseNumber: String,
        caseNumberOrder: Int64,
        email: String?,
        favoriteId: Int64?,
        phone1: String?,
        phone2: String?,
        plusCode: String?,
        svi: Double?,
        reportedBy: Int64?,
        what3Words: String?
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE OR ROLLBACK worksite
                SET
                autoContactFrequencyT=COALESCE(autoContactFrequencyT, :autoContactFrequencyT),
                caseNumber  =CASE WHEN LENGTH(caseNumber)==0 THEN :caseNumber ELSE caseNumber END,
                caseNumberOrder=CASE WHEN LENGTH(caseNumber)==0 THEN :caseNumberOrder ELSE caseNumberOrder END,
                email       =COALESCE(email, :email),
                favoriteId  =COALESCE(favoriteId, :favoriteId),
                phone1      =CASE WHEN LENGTH(COALESCE(phone1,''))<2 THEN :phone1 ELSE phone1 END,
                phone2      =COALESCE(phone2, :phone2),
                plusCode    =COALESCE(plusCode, :plusCode),
                reportedBy  =COALESCE(reportedBy, :reportedBy),
                svi         =COALESCE(svi, :svi),
                what3Words  =COALESCE(what3Words, :what3Words)
                WHERE id=:id
                """,
            arguments: [
                "id": id,
                "autoContactFrequencyT": autoContactFrequencyT,
                "caseNumber": caseNumber,
                "caseNumberOrder": caseNumberOrder,
                "email": email,
                "favoriteId": favoriteId,
                "phone1": phone1,
                "phone2": phone2,
                "plusCode": plusCode,
                "reportedBy": reportedBy,
                "svi": svi,
                "what3Words": what3Words,
            ])
    }

    static func getWorksiteId(
        _ db: Database,
        _ networkId: Int64
    ) throws -> Int64? {
        try WorksiteRecord
            .filter(Columns.networkId == networkId)
            .fetchAll(db)
            .first!
            .id
    }

    static func getCount(
        _ db: Database,
        _ incidentId: Int64,
        south: Double,
        north: Double,
        west: Double,
        east: Double
    ) throws -> Int {
        try WorksiteRecord
            .filter(
                Columns.incidentId == incidentId &&
                Columns.longitude > west &&
                Columns.longitude < east &&
                Columns.latitude < north &&
                Columns.latitude > south
            )
            .fetchCount(db)
    }

    static var visualColumns: [SQLSelectable] {
        [
            Columns.incidentId, // Map (UI) needs incident ID
            Columns.latitude,
            Columns.longitude,
            Columns.keyWorkTypeStatus,
            Columns.keyWorkTypeType,
            Columns.keyWorkTypeOrgClaim,
            Columns.favoriteId,
            Columns.createdAt,
            Columns.isLocalFavorite,
            Columns.reportedBy,
            Columns.svi,
            Columns.updatedAt
        ]
    }
}

fileprivate typealias WorksiteColumns = WorksiteRecord.Columns
extension DerivableRequest<WorksiteRecord> {
    func orderByUpdatedAtDescIdDesc() -> Self {
        order(
            WorksiteColumns.updatedAt.desc,
            WorksiteColumns.id.desc
        )
    }

    func byBounds(
        alias: TableAlias,
        south: Double,
        north: Double,
        west: Double,
        east: Double
    ) -> Self {
        filter(
            alias[WorksiteColumns.longitude] > west &&
            alias[WorksiteColumns.longitude] < east &&
            alias[WorksiteColumns.latitude] > south &&
            alias[WorksiteColumns.latitude] < north
        )
    }

    func selectNetworkId() -> Self {
        select(WorksiteColumns.networkId)
    }

    func selectIncidentId() -> Self {
        select(WorksiteColumns.incidentId)
    }

    func selectPendingSyncColumns() -> Self {
        select(
            WorksiteColumns.id,
            WorksiteColumns.caseNumber,
            WorksiteColumns.incidentId,
            WorksiteColumns.networkId
        )
    }

    func orderByName() -> Self {
        order(
            WorksiteColumns.name,
            WorksiteColumns.county,
            WorksiteColumns.city,
            WorksiteColumns.caseNumberOrder,
            WorksiteColumns.caseNumber
        )
    }

    func orderByCity() -> Self {
        order(
            WorksiteColumns.city,
            WorksiteColumns.name,
            WorksiteColumns.caseNumberOrder,
            WorksiteColumns.caseNumber
        )
    }

    func orderByCounty() -> Self {
        order(
            WorksiteColumns.county,
            WorksiteColumns.name,
            WorksiteColumns.caseNumberOrder,
            WorksiteColumns.caseNumber
        )
    }

    func orderByCaseNumber() -> Self {
        order(
            WorksiteColumns.caseNumberOrder,
            WorksiteColumns.caseNumber
        )
    }

    func orderById() -> Self {
        order(WorksiteColumns.id)
    }

    func bySviLte(_ svi: Double) -> Self {
        filter(WorksiteColumns.svi == nil || WorksiteColumns.svi <= svi)
    }

    func orderBySvi() -> Self {
        order(WorksiteColumns.svi)
    }

    func byUpdatedGte(_ reference: Date) -> Self {
        filter(WorksiteColumns.updatedAt >= reference)
    }

    func orderByUpdatedAt() -> Self {
        order(WorksiteColumns.updatedAt)
    }

    func byUpdatedBetween(_ lower: Date, _ upper: Date) -> Self {
        filter(
            WorksiteColumns.updatedAt >= lower &&
            WorksiteColumns.updatedAt <= upper
        )
    }

    func byCreatedBetween(_ lower: Date, _ upper: Date) -> Self {
        filter(
            WorksiteColumns.createdAt != nil &&
            WorksiteColumns.createdAt >= lower &&
            WorksiteColumns.createdAt <= upper
        )
    }

    func orderByCreatedAt() -> Self {
        order(WorksiteColumns.createdAt)
    }
}

// MARK: - Work type

// sourcery: copyBuilder
struct WorkTypeRecord : Identifiable, Equatable {
    static let worksite = belongsTo(WorksiteRootRecord.self)

    var id: Int64?
    let networkId: Int64
    let worksiteId: Int64
    let createdAt: Date?
    let orgClaim: Int64?
    let nextRecurAt: Date?
    let phase: Int?
    let recur: String?
    let status: String
    let workType: String

    static func create(
        worksiteId: Int64,
        createdAt: Date,
        status: String,
        workType: String
    ) -> WorkTypeRecord {
        WorkTypeRecord(
            networkId: -1,
            worksiteId: worksiteId,
            createdAt: createdAt,
            orgClaim: nil,
            nextRecurAt: nil,
            phase: nil,
            recur: nil,
            status: status,
            workType: workType
        )
    }

    func asExternalModel() -> WorkType {
        WorkType(
            id: id!,
            createdAt: createdAt,
            orgClaim: orgClaim,
            nextRecurAt: nextRecurAt,
            phase: phase,
            recur: recur,
            statusLiteral: status,
            workTypeLiteral: workType
        )
    }
}

extension WorkTypeRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "workType"

    internal enum Columns: String, ColumnExpression {
        case id,
             networkId,
             worksiteId,
             createdAt,
             orgClaim,
             nextRecurAt,
             phase,
             recur,
             status,
             workType
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static func syncDeleteUnspecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ networkIds: [Int64]
    ) throws {
        try WorkTypeRecord
            .filter(Columns.worksiteId == worksiteId && !networkIds.contains(Columns.networkId))
            .deleteAll(db)
    }

    static func deleteUnspecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ keepWorkTypes: Set<String>
    ) throws {
        try WorkTypeRecord
            .filter(Columns.worksiteId == worksiteId && !keepWorkTypes.contains(Columns.workType))
            .deleteAll(db)
    }

    static func deleteSpecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ workTypes: Set<String>
    ) throws {
        try WorkTypeRecord
            .filter(Columns.worksiteId == worksiteId && workTypes.contains(Columns.workType))
            .deleteAll(db)
    }

    func syncUpsert(_ db: Database) throws {
        let inserted = try insertAndFetch(db, onConflict: .ignore)
        if inserted == nil {
            try db.execute(
                sql:
                    """
                    UPDATE workType SET
                    createdAt   =COALESCE(:createdAt, createdAt),
                    orgClaim    =:orgClaim,
                    networkId   =:networkId,
                    nextRecurAt =:nextRecurAt,
                    phase       =:phase,
                    recur       =:recur,
                    status      =:status
                    WHERE worksiteId=:worksiteId AND workType=:workType
                    """,
                arguments: [
                    "networkId": networkId,
                    "worksiteId": worksiteId,
                    "createdAt": createdAt,
                    "orgClaim": orgClaim,
                    "nextRecurAt": nextRecurAt,
                    "phase": phase,
                    "recur": recur,
                    "status": status,
                    "workType": workType,
                ]
            )
        }
    }

    static func getWorkTypes(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> [String] {
        return try WorkTypeRecord
            .select(Columns.workType, as: String.self)
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    internal static func getWorkTypeRecords(_ db: Database, _ worksiteId: Int64) throws -> [WorkTypeRecord] {
        try WorkTypeRecord
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    static func getUnsyncedCount(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> Int {
        try WorkTypeRecord
            .filter(Columns.worksiteId == worksiteId && Columns.networkId <= 0)
            .fetchCount(db)
    }

    static func updateNetworkId(
        _ db: Database,
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try db.updateWorkTypeNetworkId(id, networkId)
    }

    static func updateNetworkId(
        _ db: Database,
        _ worksiteId: Int64,
        _ workType: String,
        _ networkId: Int64
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE OR IGNORE workType
                SET networkId =:networkId
                WHERE worksiteId=:worksiteId AND workType=:workType
                """,
            arguments: [
                "worksiteId": worksiteId,
                "workType": workType,
                "networkId": networkId
            ]
        )
    }
}

extension DerivableRequest<WorkTypeRecord> {
    func selectIdNetworkIdColumns() -> Self {
        select(WorkTypeRecord.Columns.id, WorkTypeRecord.Columns.networkId)
    }

    func filterByUnsynced(_ worksiteId: Int64) -> Self {
        filter(
            WorkTypeRecord.Columns.worksiteId == worksiteId &&
            WorkTypeRecord.Columns.networkId <= 0
        )
    }
}

// MARK: - Form data

// sourcery: copyBuilder
struct WorksiteFormDataRecord : Identifiable, Equatable {
    static let worksite = belongsTo(WorksiteRootRecord.self)

    var id: Int64?
    let worksiteId: Int64
    let fieldKey: String
    let isBoolValue: Bool
    let valueString: String
    let valueBool: Bool

    init(
        _ id: Int64?,
        _ worksiteId: Int64,
        _ fieldKey: String,
        _ isBoolValue: Bool,
        _ valueString: String,
        _ valueBool: Bool
    ) {
        self.id = id
        self.worksiteId = worksiteId
        self.fieldKey = fieldKey
        self.isBoolValue = isBoolValue
        self.valueString = valueString
        self.valueBool = valueBool
    }

    func asExternalModel() -> WorksiteFormValue {
        WorksiteFormValue(
            isBoolean: isBoolValue,
            valueString: valueString,
            valueBoolean: valueBool
        )
    }
}

extension WorksiteFormDataRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "worksiteFormData"

    internal enum Columns: String, ColumnExpression {
        case id,
             worksiteId,
             fieldKey,
             isBoolValue,
             valueString,
             valueBool
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static func deleteUnspecifiedKeys(
        _ db: Database,
        _ worksiteId: Int64,
        _ fieldKeys: Set<String>
    ) throws {
        try WorksiteFormDataRecord
            .filter(Columns.worksiteId == worksiteId && !fieldKeys.contains(Columns.fieldKey))
            .deleteAll(db)
    }

    static func getDataKeys(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> [String] {
        return try WorksiteFormDataRecord
            .select(Columns.fieldKey, as: String.self)
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    internal static func getFormData(_ db: Database, _ worksiteId: Int64) throws -> [WorksiteFormDataRecord] {
        try WorksiteFormDataRecord
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }
}

// MARK: - Flag

// sourcery: copyBuilder
struct WorksiteFlagRecord : Identifiable, Equatable {
    static let worksite = belongsTo(WorksiteRootRecord.self)

    var id: Int64?
    let networkId: Int64
    let worksiteId: Int64
    let action: String?
    let createdAt: Date
    let isHighPriority: Bool?
    let notes: String?
    let reasonT: String
    let requestedAction: String?

    init(
        _ id: Int64? = nil,
        _ networkId: Int64,
        _ worksiteId: Int64,
        _ action: String?,
        _ createdAt: Date,
        _ isHighPriority: Bool?,
        _ notes: String?,
        _ reasonT: String,
        _ requestedAction: String?
    ) {
        self.id = id
        self.networkId = networkId
        self.worksiteId = worksiteId
        self.action = action
        self.createdAt = createdAt
        self.isHighPriority = isHighPriority
        self.notes = notes
        self.reasonT = reasonT
        self.requestedAction = requestedAction
    }

    func asExternalModel(_ translator: KeyTranslator? = nil) -> WorksiteFlag {
        WorksiteFlag(
            id: id!,
            action: action ?? "",
            createdAt: createdAt,
            isHighPriority: isHighPriority ?? false,
            notes: notes ?? "",
            reasonT: reasonT,
            reason: translator?.translate(reasonT) ?? reasonT,
            requestedAction: requestedAction ?? ""
        )
    }
}

extension WorksiteFlagRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "worksiteFlag"

    internal enum Columns: String, ColumnExpression {
        case id,
             networkId,
             worksiteId,
             action,
             createdAt,
             isHighPriority,
             notes,
             reasonT,
             requestedAction
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static func syncDeleteUnspecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ reasons: [String]
    ) throws {
        try WorksiteFlagRecord
            .filter(Columns.worksiteId == worksiteId && !reasons.contains(Columns.reasonT))
            .deleteAll(db)
    }

    static func deleteUnspecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ ids: Set<Int64>
    ) throws {
        try WorksiteFlagRecord
            .filter(Columns.worksiteId == worksiteId && !ids.contains(Columns.id))
            .deleteAll(db)
    }

    static func getReasons(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> [String] {
        return try WorksiteFlagRecord
            .select(Columns.reasonT, as: String.self)
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    internal static func getFlags(_ db: Database, _ worksiteId: Int64) throws -> [WorksiteFlagRecord] {
        try WorksiteFlagRecord
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    static func getUnsyncedCount(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> Int {
        try WorksiteFlagRecord
            .filter(Columns.worksiteId == worksiteId && Columns.networkId <= 0)
            .fetchCount(db)
    }

    static func updateNetworkId(
        _ db: Database,
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try db.updateWorksiteFlagNetworkId(id, networkId)
    }
}

extension DerivableRequest<WorksiteFlagRecord> {
    func selectIdNetworkIdColumns() -> Self {
        select(WorksiteFlagRecord.Columns.id, WorksiteFlagRecord.Columns.networkId)
    }

    func filterByUnsynced(_ worksiteId: Int64) -> Self {
        filter(
            WorksiteFlagRecord.Columns.worksiteId == worksiteId &&
            WorksiteFlagRecord.Columns.networkId <= 0
        )
    }
}

// MARK: - Note

// sourcery: copyBuilder
struct WorksiteNoteRecord : Identifiable, Equatable {
    static let worksite = belongsTo(WorksiteRootRecord.self)

    var id: Int64?
    let localGlobalUuid: String
    let networkId: Int64
    let worksiteId: Int64
    let createdAt: Date
    let isSurvivor: Bool
    let note: String

    init(
        _ id: Int64?,
        _ localGlobalUuid: String,
        _ networkId: Int64,
        _ worksiteId: Int64,
        _ createdAt: Date,
        _ isSurvivor: Bool,
        _ note: String
    ) {
        self.id = id
        self.localGlobalUuid = localGlobalUuid
        self.networkId = networkId
        self.worksiteId = worksiteId
        self.createdAt = createdAt
        self.isSurvivor = isSurvivor
        self.note = note
    }

    func asExternalModel() -> WorksiteNote {
        WorksiteNote(
            id!,
            createdAt,
            isSurvivor,
            note
        )
    }
}

extension WorksiteNoteRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String = "worksiteNote"

    internal enum Columns: String, ColumnExpression {
        case id,
             localGlobalUuid,
             networkId,
             worksiteId,
             createdAt,
             isSurvivor,
             note
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    func syncUpsert(_ db: Database) throws {
        let inserted = try insertAndFetch(db, onConflict: .ignore)
        if inserted == nil {
            try db.execute(
                sql:
                    """
                    UPDATE worksiteNote SET
                           createdAt    =:createdAt,
                           isSurvivor   =:isSurvivor,
                           note         =:note
                    WHERE worksiteId=:worksiteId AND networkId=:networkId AND localGlobalUuid=''
                    """,
                arguments: [
                    "worksiteId": worksiteId,
                    "networkId": networkId,
                    "createdAt": createdAt,
                    "isSurvivor": isSurvivor,
                    "note": note,
                ]
            )
        }
    }

    static func syncDeleteUnspecified(
        _ db: Database,
        _ worksiteId: Int64,
        _ networkIds: [Int64]
    ) throws {
        try WorksiteNoteRecord
            .filter(Columns.worksiteId == worksiteId && !networkIds.contains(Columns.networkId))
            .deleteAll(db)
    }

    static func getNotes(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> [String] {
        return try getNotes(db, worksiteId, Date.now.addingTimeInterval(-12.hours))
    }

    static func getNotes(
        _ db: Database,
        _ worksiteId: Int64,
        _ createdAt: Date
    ) throws -> [String] {
        return try WorksiteNoteRecord
            .select(Columns.note, as: String.self)
            .filter(Columns.worksiteId == worksiteId && Columns.createdAt > createdAt)
            .fetchAll(db)
    }

    internal static func getNoteRecords(_ db: Database, _ worksiteId: Int64) throws -> [WorksiteNoteRecord] {
        try WorksiteNoteRecord
            .filter(Columns.worksiteId == worksiteId)
            .fetchAll(db)
    }

    static func getUnsyncedCount(
        _ db: Database,
        _ worksiteId: Int64
    ) throws -> Int {
        try WorksiteNoteRecord
            .filter(Columns.worksiteId == worksiteId && Columns.networkId <= 0)
            .fetchCount(db)
    }

    static func updateNetworkId(
        _ db: Database,
        _ id: Int64,
        _ networkId: Int64
    ) throws {
        try db.execute(
            sql:
                """
                UPDATE OR IGNORE worksiteNote
                SET networkId       =:networkId,
                    localGlobalUuid =''
                WHERE id=:id
                """,
            arguments: [
                "id": id,
                "networkId": networkId
            ]
        )
    }
}

extension DerivableRequest<WorksiteNoteRecord> {
    func selectIdNetworkIdColumns() -> Self {
        select(WorksiteNoteRecord.Columns.id, WorksiteNoteRecord.Columns.networkId)
    }

    func filterByUnsynced(_ worksiteId: Int64) -> Self {
        filter(
            WorksiteNoteRecord.Columns.worksiteId == worksiteId &&
            WorksiteNoteRecord.Columns.networkId <= 0
        )
    }
}
