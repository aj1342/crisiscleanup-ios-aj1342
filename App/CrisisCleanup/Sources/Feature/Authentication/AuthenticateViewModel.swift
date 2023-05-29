import Combine
import SwiftUI

class AuthenticateViewModel: ObservableObject {
    private let appEnv: AppEnv
    let appSettings: AppSettingsProvider
    private let authApi: CrisisCleanupAuthApi
    private let inputValidator: InputValidator
    private let accessTokenDecoder: AccessTokenDecoder
    private let accountDataRepository: AccountDataRepository
    private let authEventBus: AuthEventBus
    private let logger: AppLogger

    let isDebuggable: Bool

    @Published var viewData: AuthenticateViewData = AuthenticateViewData()

    @Published var errorMessage: String = ""
    @Published var passwordHasFocus: Bool = false
    @Published var emailHasFocus: Bool = false

    @Published var isAuthenticating: Bool = false

    private var disposables = Set<AnyCancellable>()

    init(
        appEnv: AppEnv,
        appSettings: AppSettingsProvider,
        authApi: CrisisCleanupAuthApi,
        inputValidator: InputValidator,
        accessTokenDecoder: AccessTokenDecoder,
        accountDataRepository: AccountDataRepository,
        authEventBus: AuthEventBus,
        loggerFactory: AppLoggerFactory
    ) {
        self.appEnv = appEnv
        self.appSettings = appSettings
        self.authApi = authApi
        self.inputValidator = inputValidator
        self.accessTokenDecoder = accessTokenDecoder
        self.accountDataRepository = accountDataRepository
        self.authEventBus = authEventBus
        logger = loggerFactory.getLogger("auth")

        isDebuggable = appEnv.isDebuggable

        accountDataRepository.accountData
            .receive(on: RunLoop.main)
            .sink { data in
                self.viewData = AuthenticateViewData(
                    state: .ready,
                    accountData: data
                )
            }
            .store(in: &disposables)
    }

    private func resetVisualState() {
        errorMessage = ""
        emailHasFocus = false
        passwordHasFocus = false
    }

    private func validateInput(_ emailAddress: String, _ password: String) -> Bool {
        if !inputValidator.validateEmailAddress(emailAddress) {
            errorMessage = "Enter valid email error".localizedString
            emailHasFocus = true
            return false
        }

        if password.isBlank {
            errorMessage = "Enter valid password error".localizedString
            passwordHasFocus = true
            return false
        }

        return true
    }

    private func authenticateAsync(
        _ emailAddress: String,
        _ password: String
    ) async -> LoginResult {
        var errorKey = ""

        do {
            let result = try await authApi.login(emailAddress, password)
            let hasError = result.errors?.isNotEmpty == true
            if hasError {
                let logErrorMessage = result.errors?.condenseMessages ?? "Server error"
                if logErrorMessage == "Unable to log in with provided credentials." {
                    errorKey = "Invalid credentials"
                } else {
                    logger.logError(GenericError(logErrorMessage))
                }
            } else {
                let accessToken = result.accessToken!

                let expirySeconds = try Int64(accessTokenDecoder.decode(accessToken).expiresAt.timeIntervalSince1970)

                let claims = result.claims!
                let profilePicUri = claims.files?.filter { $0.isProfilePicture }.firstOrNil?.largeThumbnailUrl ?? ""

                let organization = result.organizations
                var orgData = emptyOrgData
                if organization?.isActive == true &&
                    organization!.id >= 0 &&
                    organization!.name.isNotBlank {
                    orgData = OrgData(
                        id: organization!.id,
                        name: organization!.name
                    )
                }

                let success = LoginSuccess(
                    claims: claims,
                    orgData: orgData,
                    profilePictureUri: profilePicUri,
                    accessToken: accessToken,
                    expirySeconds: expirySeconds
                )
                return LoginResult(errorMessage: "", success: success   )
            }
        } catch {
            errorKey = "Unknown auth error"
        }

        return LoginResult(
            errorMessage: errorKey.localizedString,
            success: nil
        )
    }

    func authenticate(_ emailAddress: String, _ password: String) {
        if isAuthenticating {
            return
        }

        resetVisualState()

        if !validateInput(emailAddress, password) {
            return
        }

        isAuthenticating = true
        Task { @MainActor in
            defer {
                isAuthenticating = false
            }

            let loginResult = await authenticateAsync(emailAddress, password)
            if let result = loginResult.success {
                with (result) { r in
                    accountDataRepository.setAccount(
                        id: r.claims.id,
                        accessToken: r.accessToken,
                        email: r.claims.email,
                        firstName: r.claims.firstName,
                        lastName: r.claims.lastName,
                        expirySeconds: r.expirySeconds,
                        profilePictureUri: r.profilePictureUri,
                        org: r.orgData
                    )
                }
            } else {
                errorMessage = loginResult.errorMessage
            }
        }
    }

    func logout() {
        authEventBus.onLogout()
    }
}

fileprivate struct LoginSuccess {
    let claims: NetworkAuthUserClaims
    let orgData: OrgData
    let profilePictureUri: String
    let accessToken: String
    let expirySeconds: Int64
}

fileprivate struct LoginResult {
    let errorMessage: String
    let success: LoginSuccess?
}