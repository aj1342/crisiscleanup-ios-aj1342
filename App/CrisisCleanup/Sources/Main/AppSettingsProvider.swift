public protocol AppSettingsProvider {
    var apiBaseUrl: String { get }
    var baseUrl: String { get }
    var reachabilityHost: String { get }

    var googleMapsApiKey: String { get }

    var debugEmailAddress: String { get }
    var debugAccountPassword: String { get }
}
