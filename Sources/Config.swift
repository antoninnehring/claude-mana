import Foundation

struct Config: Codable {
    let apiKey: String?
    let organizationId: String?
    let dailyTokenLimit: Int?
    let monthlyTokenLimit: Int?
    let refreshIntervalSeconds: Int?
    let manualLevel: Double?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case organizationId = "organization_id"
        case dailyTokenLimit = "daily_token_limit"
        case monthlyTokenLimit = "monthly_token_limit"
        case refreshIntervalSeconds = "refresh_interval_seconds"
        case manualLevel = "manual_level"
    }
}
