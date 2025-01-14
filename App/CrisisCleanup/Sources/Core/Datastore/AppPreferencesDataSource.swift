import Combine
import Foundation

// Should be named *DataSource. Minor transgression. Correction not necessary.
public protocol AppPreferencesDataStore {
    var preferences: any Publisher<AppPreferences, Never> { get }

    func setSyncAttempt(
        _ isSuccessful: Bool,
        _ attemptedSeconds: Double
    )
    func clearSyncData()
    func setSelectedIncident(_ id: Int64)
    func setLanguageKey(_ key: String)
    func setTableViewSortBy(_ sortBy: WorksiteSortBy)
}

extension AppPreferencesDataStore {
    func setSyncAttempt(_ isSuccessful: Bool) {
        setSyncAttempt(isSuccessful, Date().timeIntervalSince1970)
    }
}

fileprivate let jsonDecoder = JsonDecoderFactory().decoder()
fileprivate let jsonEncoder = JsonEncoderFactory().encoder()

class AppPreferencesUserDefaults: AppPreferencesDataStore {
    let preferences: any Publisher<AppPreferences, Never>

    private func update(_ preferences: AppPreferences) {
        UserDefaults.standard.appPreferences = preferences
    }

    init() {
        preferences = UserDefaults.standard.publisher(for: \.appPreferencesData)
            .map { preferencesData in
                let appPreferences: AppPreferences
                if preferencesData != nil,
                   let data = try? jsonDecoder.decode(AppPreferences.self, from: preferencesData!) {
                    appPreferences = data
                } else {
                    appPreferences = AppPreferences()
                }
                return appPreferences
            }
    }

    func setSyncAttempt(
        _ isSuccessful: Bool,
        _ attemptedSeconds: Double
    ) {
        let preferences = UserDefaults.standard.appPreferences
        let previousAttempt = preferences.syncAttempt
        let successfulSeconds = isSuccessful ? attemptedSeconds : previousAttempt.successfulSeconds
        let attemptedCounter = isSuccessful ? 0 : previousAttempt.attemptedCounter + 1
        let attempt = SyncAttempt(
            successfulSeconds: successfulSeconds,
            attemptedSeconds: attemptedSeconds,
            attemptedCounter: attemptedCounter
        )
        update(
            preferences.copy { $0.syncAttempt = attempt }
        )
    }

    func clearSyncData() {
        update(UserDefaults.standard.appPreferences.copy {
            $0.syncAttempt = SyncAttempt()
        })
    }

    func setSelectedIncident(_ id: Int64) {
        update(
            UserDefaults.standard.appPreferences.copy {
                $0.selectedIncidentId = id
            }
        )
    }

    func setLanguageKey(_ key: String) {
        update(
            UserDefaults.standard.appPreferences.copy {
                $0.languageKey = key
            }
        )
    }

    func setTableViewSortBy(_ sortBy: WorksiteSortBy) {
        update(
            UserDefaults.standard.appPreferences.copy {
                $0.tableViewSortBy = sortBy
            }
        )
    }
}

fileprivate let appPreferencesKey = "app_preferences"
extension UserDefaults {
    @objc dynamic fileprivate(set) var appPreferencesData: Data? {
        get { data(forKey: appPreferencesKey) }
        set { set(newValue, forKey: appPreferencesKey) }
    }

    var appPreferences: AppPreferences {
        get {
            if let data = appPreferencesData,
               let preferences = try? jsonDecoder.decode(AppPreferences.self, from: data) {
                return preferences
            }
            return AppPreferences()
        }
        set {
            if let data = try? jsonEncoder.encode(newValue) {
                appPreferencesData = data
            }
        }
    }
}
