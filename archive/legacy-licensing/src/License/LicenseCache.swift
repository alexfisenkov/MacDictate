import Foundation

final class LicenseCache {
    private let userDefaults: UserDefaults
    private let cacheKey: String
    private let offlineGraceInterval: TimeInterval
    private let expiryGraceInterval: TimeInterval

    init(
        userDefaults: UserDefaults = .standard,
        cacheKey: String = "MacDictateLicenseSnapshot",
        offlineGraceInterval: TimeInterval = 72 * 60 * 60,
        expiryGraceInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.userDefaults = userDefaults
        self.cacheKey = cacheKey
        self.offlineGraceInterval = offlineGraceInterval
        self.expiryGraceInterval = expiryGraceInterval
    }

    func load(machineID: String) -> LicenseSnapshot? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(LicenseSnapshot.self, from: data),
              snapshot.machineID == machineID else {
            return nil
        }

        return snapshot
    }

    func persist(_ snapshot: LicenseSnapshot?) {
        guard let snapshot else {
            userDefaults.removeObject(forKey: cacheKey)
            return
        }

        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }

    func graceDeadline(for snapshot: LicenseSnapshot) -> Date? {
        guard snapshot.isActive else { return nil }

        let boundedByCheck = snapshot.checkedAt.addingTimeInterval(offlineGraceInterval)
        guard let expiresAt = snapshot.expiresAt else { return boundedByCheck }
        return min(boundedByCheck, expiresAt.addingTimeInterval(expiryGraceInterval))
    }
}
