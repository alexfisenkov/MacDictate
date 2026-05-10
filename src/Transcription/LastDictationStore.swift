import Foundation

struct LastDictationEntry: Codable, Equatable {
    let text: String
    let createdAt: Date
}

final class LastDictationStore {
    static let storageKey = "MacDictateLastDictation"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(_ text: String, createdAt: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = LastDictationEntry(text: trimmed, createdAt: createdAt)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    func latest() -> LastDictationEntry? {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(LastDictationEntry.self, from: data)
    }

    func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }
}
