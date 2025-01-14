import Foundation

public protocol NetworkRequestProvider {
    func apiUrl(_ path: String) -> URL
}

extension NetworkRequestProvider {
    var login: NetworkRequest {
        NetworkRequest(
            apiUrl("api-token-auth"),
            method: .post
        )
    }

    var oauthLogin: NetworkRequest {
        NetworkRequest(
            apiUrl("api-mobile-auth"),
            method: .post
        )
    }

    var refreshAccountTokens: NetworkRequest {
        NetworkRequest(
            apiUrl("api-mobile-refresh-token"),
            method: .post
        )
    }

    var accountProfile: NetworkRequest {
        NetworkRequest(
            apiUrl("users/me"),
            addTokenHeader: true
        )
    }

    var organizations: NetworkRequest {
        NetworkRequest(
            apiUrl("organizations"),
            addTokenHeader: true
        )
    }

    var languages: NetworkRequest {
        NetworkRequest(apiUrl("languages"))
    }

    var languageTranslations: NetworkRequest {
        NetworkRequest(
            apiUrl("languages")
        )
    }

    var localizationCount: NetworkRequest {
        NetworkRequest(apiUrl("localizations/count"))
    }

    var workTypeStatuses: NetworkRequest {
        NetworkRequest(apiUrl("statuses"))
    }

    var incidents: NetworkRequest {
        NetworkRequest(
            apiUrl("incidents"),
            addTokenHeader: true
        )
    }

    var incidentLocations: NetworkRequest {
        NetworkRequest(
            apiUrl("locations"),
            addTokenHeader: true
        )
    }

    var incident: NetworkRequest {
        NetworkRequest(
            apiUrl("incidents"),
            addTokenHeader: true
        )
    }

    var incidentOrganizations: NetworkRequest {
        NetworkRequest(
            apiUrl("incidents"),
            addTokenHeader: true
        )
    }

    var worksitesCoreData: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            addTokenHeader: true
        )
    }

    var worksitesLocationSearch: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            addTokenHeader: true
        )
    }

    var worksitesSearch: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites_all"),
            addTokenHeader: true
        )
    }

    var worksites: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            addTokenHeader: true
        )
    }

    var worksitesCount: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites/count"),
            addTokenHeader: true
        )
    }

    var worksitesPage: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites_page"),
            addTokenHeader: true
        )
    }

    var workTypeRequests: NetworkRequest {
        NetworkRequest(
            apiUrl("worksite_requests"),
            addTokenHeader: true
        )
    }

    var users: NetworkRequest {
        NetworkRequest(
            apiUrl("users"),
            addTokenHeader: true
        )
    }

    var caseHistory: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            addTokenHeader: true
        )
    }

    // MARK: Write requests

    var newWorksite: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var updateWorksite: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var favorite: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var unfavorite: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .delete,
            addTokenHeader: true
        )
    }

    var addFlag: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var deleteFlag: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .delete,
            addTokenHeader: true
        )
    }

    var addNote: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var updateWorkTypeStatus: NetworkRequest {
        NetworkRequest(
            apiUrl("worksite_work_types"),
            method: .patch,
            addTokenHeader: true
        )
    }

    var claimWorkTypes: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var unclaimWorkTypes: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var requestWorkTypes: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var releaseWorkTypes: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var deleteFile: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .delete,
            addTokenHeader: true
        )
    }

    var startFileUpload: NetworkRequest {
        NetworkRequest(
            apiUrl("files"),
            method: .post,
            addTokenHeader: true
        )
    }

    var addUploadedFile: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }

    var shareWorksite: NetworkRequest {
        NetworkRequest(
            apiUrl("worksites"),
            method: .post,
            addTokenHeader: true
        )
    }
}

class CrisisCleanupNetworkRequestProvider: NetworkRequestProvider {
    let baseUrl: URL

    init(_ appSettings: AppSettingsProvider) {
        baseUrl = try! appSettings.apiBaseUrl.asURL()
    }

    func apiUrl(_ path: String) -> URL {
        return baseUrl.appendingPathComponent(path)
    }
}
