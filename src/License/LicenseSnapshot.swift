import Foundation

struct LicenseSnapshot: Codable {
    let machineID: String
    let isPaid: Bool
    let isActive: Bool
    let daysLeft: Int
    let expiresAt: Date?
    let checkedAt: Date
}

struct LicenseStatusResponse: Decodable {
    let deviceId: String
    let isPaid: Bool
    let isActive: Bool
    let expiresAt: String?
    let daysLeft: Int
}
