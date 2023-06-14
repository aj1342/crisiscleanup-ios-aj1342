import Foundation

private let releaseDaysThreshold = 30.days

// sourcery: copyBuilder
public struct WorkType {
    let id: Int64
    let createdAt: Date?
    let orgClaim: Int64?
    let nextRecurAt: Date?
    let phase: Int?
    let recur: String?
    let statusLiteral: String
    let workTypeLiteral: String

    // sourcery:begin: skipCopy
    lazy var isClaimed: Bool = { orgClaim != nil }()
    lazy var status: WorkTypeStatus = { statusFromLiteral(statusLiteral) }()
    lazy var statusClaim = { WorkTypeStatusClaim(status, isClaimed) }()
    lazy var workType: WorkTypeType = { typeFromLiteral(workTypeLiteral) }()

    var isReleaseEligible: Bool {
        if let at = createdAt {
            return Date.now.addingTimeInterval(releaseDaysThreshold) > at
        }
        return false
    }
    // sourcery:end

    init(
        id: Int64,
        createdAt: Date? = nil,
        orgClaim: Int64? = nil,
        nextRecurAt: Date? = nil,
        phase: Int? = nil,
        recur: String? = nil,
        statusLiteral: String,
        workTypeLiteral: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.orgClaim = orgClaim
        self.nextRecurAt = nextRecurAt
        self.phase = phase
        self.recur = recur
        self.statusLiteral = statusLiteral
        self.workTypeLiteral = workTypeLiteral
    }
}

public enum WorkTypeStatus: String, Identifiable, CaseIterable {
    case unknown
    case openAssigned
    case openUnassigned
    case openPartiallyCompleted
    case openNeedsFollowUp
    case openUnresponsive
    case closedCompleted
    case closedIncomplete
    case closedOutOfScope
    case closedDoneByOthers
    case closedNoHelpWanted
    case closedDuplicate
    case closedRejected

    public var id: String { rawValue }

    var literal: String {
        switch self {
        case .unknown: return "unknown"
        case .openAssigned: return "open_assigned"
        case .openUnassigned: return "open_unassigned"
        case .openPartiallyCompleted: return "open_partially-completed"
        case .openNeedsFollowUp: return "open_needs-follow-up"
        case .openUnresponsive: return "open_unresponsive"
        case .closedCompleted: return "closed_completed"
        case .closedIncomplete: return "closed_incomplete"
        case .closedOutOfScope: return "closed_out-of-scope"
        case .closedDoneByOthers: return "closed_done-by-others"
        case .closedNoHelpWanted: return "closed_no-help-wanted"
        case .closedDuplicate: return "closed_duplicate"
        case .closedRejected: return "closed_rejected"
        }
    }
}


fileprivate let literalStatusLookup = WorkTypeStatus.allCases.associateBy{ $0.literal }
func statusFromLiteral(_ literal: String) -> WorkTypeStatus { literalStatusLookup[literal] ?? WorkTypeStatus.unknown
}

public struct WorkTypeStatusClaim {
    let status: WorkTypeStatus
    let isClaimed: Bool

    init(
        _ status: WorkTypeStatus,
        _ isClaimed: Bool
    ) {
        self.status = status
        self.isClaimed = isClaimed
    }

    static func getType(type: String) -> WorkTypeType {
        return typeFromLiteral(type)
    }

    static func make(_ status: String, _ orgId: Int64?) -> WorkTypeStatusClaim {
        WorkTypeStatusClaim(
            statusFromLiteral(status),
            orgId != nil
        )
    }
}

private func typeFromLiteral(_ type: String) -> WorkTypeType {
    switch type.lowercased() {
    case "ash": return WorkTypeType.ash
    case "animal_services": return WorkTypeType.animalServices
    case "catchment_gutters": return WorkTypeType.catchmentGutters
    case "chimney_capping": return WorkTypeType.chimneyCapping
    case "construction_consultation": return WorkTypeType.constructionConsultation
    case "core_relief_items": return WorkTypeType.coreReliefItems
    case "demolition": return WorkTypeType.demolition
    case "debris": return WorkTypeType.debris
    case "deferred_maintenance": return WorkTypeType.deferredMaintenance
    case "domestic_services": return WorkTypeType.domesticServices
    case "erosion": return WorkTypeType.erosion
    case "escort": return WorkTypeType.escort
    case "fence": return WorkTypeType.fence
    case "fire": return WorkTypeType.fire
    case "food": return WorkTypeType.food
    case "landslide": return WorkTypeType.landslide
    case "leak": return WorkTypeType.leak
    case "meals": return WorkTypeType.meals
    case "mold_remediation": return WorkTypeType.moldRemediation
    case "muck_out": return WorkTypeType.muckOut
    case "other": return WorkTypeType.other
    case "oxygen": return WorkTypeType.oxygen
    case "pipe": return WorkTypeType.pipe
    case "ppe": return WorkTypeType.ppe
    case "prescription": return WorkTypeType.prescription
    case "rebuild_total": return WorkTypeType.rebuildTotal
    case "rebuild": return WorkTypeType.rebuild
    case "retardant_cleanup": return WorkTypeType.retardantCleanup
    case "sandbagging": return WorkTypeType.sandbagging
    case "shelter": return WorkTypeType.shelter
    case "shopping": return WorkTypeType.shopping
    case "smoke_damage": return WorkTypeType.smokeDamage
    case "snow_ground": return WorkTypeType.snowGround
    case "snow_roof": return WorkTypeType.snowRoof
    case "structure": return WorkTypeType.structure
    case "tarp": return WorkTypeType.tarp
    case "temporary_housing": return WorkTypeType.temporaryHousing
    case "trees_heavy_equipment": return WorkTypeType.treesHeavyEquipment
    case "trees": return WorkTypeType.trees
    case "water_bottles": return WorkTypeType.waterBottles
    case "wellness_check": return WorkTypeType.wellnessCheck
    default: return WorkTypeType.unknown
    }
}

public enum WorkTypeType: String, Identifiable, CaseIterable {
    case animalServices
    case ash
    case catchmentGutters
    case chimneyCapping
    case constructionConsultation
    case coreReliefItems
    case debris
    case deferredMaintenance
    case demolition
    case domesticServices
    case erosion
    case escort
    case favorite
    case fence
    case fire
    case food
    case important
    case landslide
    case leak
    case meals
    case moldRemediation
    case muckOut
    case other
    case oxygen
    case pipe
    case ppe
    case prescription
    case rebuild
    case rebuildTotal
    case retardantCleanup
    case sandbagging
    case shelter
    case shopping
    case smokeDamage
    case snowGround
    case snowRoof
    case structure
    case tarp
    case temporaryHousing
    case trees
    case treesHeavyEquipment
    case unknown
    case waterBottles
    case wellnessCheck

    public var id: String { rawValue }
}