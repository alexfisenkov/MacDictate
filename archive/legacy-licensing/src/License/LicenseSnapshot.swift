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

    private enum CodingKeys: String, CodingKey {
        case deviceId
        case isPaid
        case isActive
        case expiresAt
        case daysLeft
    }

    init(
        deviceId: String,
        isPaid: Bool,
        isActive: Bool,
        expiresAt: String?,
        daysLeft: Int
    ) {
        self.deviceId = deviceId
        self.isPaid = isPaid
        self.isActive = isActive
        self.expiresAt = expiresAt
        self.daysLeft = daysLeft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        isPaid = try Self.decodeFlexibleBool(from: container, forKey: .isPaid)
        isActive = try Self.decodeFlexibleBool(from: container, forKey: .isActive)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        daysLeft = try container.decode(Int.self, forKey: .daysLeft)
    }

    private static func decodeFlexibleBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Bool {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }

        if let value = try? container.decode(Int.self, forKey: key) {
            return value != 0
        }

        if let value = try? container.decode(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(
            Bool.self,
            DecodingError.Context(
                codingPath: container.codingPath + [key],
                debugDescription: "Expected Bool, Int, or boolean-like String"
            )
        )
    }
}
