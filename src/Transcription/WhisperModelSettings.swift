import Foundation

enum WhisperModelMode: String {
    case balanced
    case maximumAccuracy
}

enum WhisperModelSettings {
    static let modeKey = "MacDictateWhisperModelMode"

    static func currentMode(userDefaults: UserDefaults = .standard) -> WhisperModelMode {
        guard let rawValue = userDefaults.string(forKey: modeKey),
              let mode = WhisperModelMode(rawValue: rawValue) else {
            return .balanced
        }

        return mode
    }

    static func setMode(_ mode: WhisperModelMode, userDefaults: UserDefaults = .standard) {
        userDefaults.set(mode.rawValue, forKey: modeKey)
    }
}
