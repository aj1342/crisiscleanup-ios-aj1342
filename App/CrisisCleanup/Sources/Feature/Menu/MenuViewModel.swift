import SwiftUI
import Combine

class MenuViewModel: ObservableObject {
    private let incidentsRepository: IncidentsRepository
    private let worksitesRepository: WorksitesRepository
    private let accountDataRepository: AccountDataRepository
    private let incidentSelector: IncidentSelector
    private let appVersionProvider: AppVersionProvider
    private let databaseVersionProvider: DatabaseVersionProvider
    private let authEventBus: AuthEventBus
    private let appEnv: AppEnv
    private let logger: AppLogger

    let isDebuggable: Bool
    let isProduction: Bool

    @Published private(set) var showHeaderLoading = false

    @Published private(set) var profilePicture: AccountProfilePicture? = nil

    @Published private(set) var incidentsData = LoadingIncidentsData

    var versionText: String {
        let version = appVersionProvider.version
        return isProduction ? version.1 : "\(version.1) (\(version.0))"
    }

    var databaseVersionText: String {
        isProduction ? "" : "DB \(databaseVersionProvider.databaseVersion)"
    }

    private var subscriptions = Set<AnyCancellable>()

    init(
        incidentsRepository: IncidentsRepository,
        worksitesRepository: WorksitesRepository,
        accountDataRepository: AccountDataRepository,
        accountDataRefresher: AccountDataRefresher,
        syncLogRepository: SyncLogRepository,
        incidentSelector: IncidentSelector,
        appVersionProvider: AppVersionProvider,
        databaseVersionProvider: DatabaseVersionProvider,
        authEventBus: AuthEventBus,
        appEnv: AppEnv,
        loggerFactory: AppLoggerFactory
    ) {
        self.incidentsRepository = incidentsRepository
        self.worksitesRepository = worksitesRepository
        self.accountDataRepository = accountDataRepository
        self.incidentSelector = incidentSelector
        self.appVersionProvider = appVersionProvider
        self.databaseVersionProvider = databaseVersionProvider
        self.authEventBus = authEventBus
        self.appEnv = appEnv
        logger = loggerFactory.getLogger("menu")

        isDebuggable = appEnv.isDebuggable
        isProduction = appEnv.isProduction

        Task {
            syncLogRepository.trimOldLogs()
            await accountDataRefresher.updateProfilePicture()
        }
    }

    func onViewAppear() {
        subscribeLoading()
        subscribeIncidentsData()
        subscribeProfilePicture()
    }

    func onViewDisappear() {
        subscriptions = cancelSubscriptions(subscriptions)
    }

    private func subscribeLoading() {
        Publishers.CombineLatest(
            incidentsRepository.isLoading.eraseToAnyPublisher(),
            worksitesRepository.isLoading.eraseToAnyPublisher()
        )
        .map { b0, b1 in b0 || b1 }
        .receive(on: RunLoop.main)
        .assign(to: \.showHeaderLoading, on: self)
        .store(in: &subscriptions)
    }

    private func subscribeIncidentsData() {
        incidentSelector.incidentsData
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .assign(to: \.incidentsData, on: self)
            .store(in: &subscriptions)
    }

    private func subscribeProfilePicture() {
        accountDataRepository.accountData
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .map {
                let pictureUrl = $0.profilePictureUri
                let isSvg = pictureUrl.hasSuffix(".svg")
                if let escapedUrl = isSvg ? pictureUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) : pictureUrl,
                   let url = URL(string: escapedUrl) {
                    return AccountProfilePicture(
                        url: url,
                        isSvg: isSvg
                    )
                }
                return nil
            }
            .assign(to: \.profilePicture, on: self)
            .store(in: &subscriptions)
    }

    func clearRefreshToken() {
        if isDebuggable {
            accountDataRepository.clearAccountTokens()
        }
    }

    func expireToken() {
        if isDebuggable {
            if let repository = accountDataRepository as? CrisisCleanupAccountDataRepository {
                repository.expireAccessToken()
            }
        }
    }
}

struct AccountProfilePicture {
    let url: URL
    let isSvg: Bool
}
