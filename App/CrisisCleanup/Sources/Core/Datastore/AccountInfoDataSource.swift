import Combine
import Foundation

protocol AccountInfoDataSource {
    var accountData: any Publisher<AccountData, Never> { get }

    func setAccount(_ info: AccountInfo)
    func clearAccount()
    func expireToken()
}

fileprivate let jsonDecoder = JsonDecoderFactory().decoder()
fileprivate let jsonEncoder = JSONEncoder()

class AccountInfoUserDefaults: AccountInfoDataSource {
    let accountData: any Publisher<AccountData, Never>

    init() {
        accountData = UserDefaults.standard.publisher(for: \.accountInfoData)
            .map { infoData in
                let accountData: AccountData
                if infoData != nil,
                   let info = try? jsonDecoder.decode(AccountInfo.self, from: infoData!) {
                    accountData = info.asAccountData()
                } else {
                    accountData = emptyAccountData
                }
                return accountData
            }
    }

    func setAccount(_ info: AccountInfo) {
        UserDefaults.standard.accountInfo = info
    }

    func clearAccount() {
        setAccount(AccountInfo())
    }

    func expireToken() {
        let info = UserDefaults.standard.accountInfo
        if info.id > 0 {
            setAccount(
                info.copy {
                    $0.expirySeconds = 0
                }
            )
        }
    }
}

fileprivate let accountInfoKey = "account_info"
extension UserDefaults {
    @objc dynamic fileprivate(set) var accountInfoData: Data? {
        get { data(forKey: accountInfoKey) }
        set { set(newValue, forKey: accountInfoKey) }
    }

    var accountInfo: AccountInfo {
        get {
            if let infoData = accountInfoData,
               let info = try? jsonDecoder.decode(AccountInfo.self, from: infoData) {
                return info
            }
            return AccountInfo()
        }
        set {
            if let infoData = try? jsonEncoder.encode(newValue) {
                accountInfoData = infoData
            }
        }
    }
}
