import Foundation

struct DebugSessionContext: Codable {
    let appVersion: String
    let textImprovementEnabled: Bool
    let machineID: String
}

struct DebugSessionEvent: Codable {
    let timestamp: Date
    let name: String
    let details: [String: String]
}

final class DebugSessionLogger {
    static let enabledKey = "MacDictateDebugSessionLoggingEnabled"

    private let baseDirectory: URL
    private let userDefaults: UserDefaults
    private let fileManager: FileManager

    init(
        baseDirectory: URL = DebugSessionLogger.defaultBaseDirectory(),
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory
        self.userDefaults = userDefaults
        self.fileManager = fileManager
    }

    static func defaultBaseDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent(".macdictate", isDirectory: true)
            .appendingPathComponent("debug-sessions", isDirectory: true)
    }

    func startSession(context: DebugSessionContext) -> DebugSession? {
        guard userDefaults.bool(forKey: Self.enabledKey) else {
            return nil
        }

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

            let timestamp = Self.sessionTimestampFormatter.string(from: Date())
            let sessionID = "\(timestamp)-\(UUID().uuidString.prefix(8))"
            let directoryURL = baseDirectory.appendingPathComponent(sessionID, isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let session = DebugSession(directoryURL: directoryURL, fileManager: fileManager)
            session.writeJSONFile("metadata.json", DebugSessionMetadata(
                sessionID: sessionID,
                createdAt: Date(),
                appVersion: context.appVersion,
                textImprovementEnabled: context.textImprovementEnabled,
                machineID: context.machineID
            ))
            session.record("session_started", details: [
                "textImprovementEnabled": String(context.textImprovementEnabled)
            ])
            return session
        } catch {
            return nil
        }
    }

    private static let sessionTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct DebugSessionMetadata: Codable {
    let sessionID: String
    let createdAt: Date
    let appVersion: String
    let textImprovementEnabled: Bool
    let machineID: String
}

final class DebugSession {
    let directoryURL: URL

    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.alexfisenkov.macdictate.debug-session")
    private let encoder: JSONEncoder

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func copyAudio(from sourcePath: String) {
        queue.sync {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = directoryURL.appendingPathComponent("audio.wav")

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                recordLocked("audio_copied", details: [
                    "bytes": String(fileSize(at: destinationURL.path) ?? 0)
                ])
            } catch {
                recordLocked("audio_copy_failed", details: ["error": error.localizedDescription])
            }
        }
    }

    func writeTextFile(_ filename: String, _ text: String) {
        queue.sync {
            do {
                try text.write(
                    to: directoryURL.appendingPathComponent(filename),
                    atomically: true,
                    encoding: .utf8
                )
                recordLocked("file_written", details: [
                    "file": filename,
                    "characters": String(text.count)
                ])
            } catch {
                recordLocked("file_write_failed", details: [
                    "file": filename,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    func writeJSONFile<T: Encodable>(_ filename: String, _ value: T) {
        queue.sync {
            do {
                let data = try encoder.encode(value)
                try data.write(to: directoryURL.appendingPathComponent(filename), options: .atomic)
                recordLocked("file_written", details: [
                    "file": filename,
                    "bytes": String(data.count)
                ])
            } catch {
                recordLocked("file_write_failed", details: [
                    "file": filename,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    func record(_ name: String, details: [String: String] = [:]) {
        queue.sync {
            recordLocked(name, details: details)
        }
    }

    func finish(finalText: String, warning: String?) {
        writeTextFile("07_final_inserted.txt", finalText)

        var details = ["finalCharacters": String(finalText.count)]
        if let warning {
            details["warning"] = warning
        }
        record("session_finished", details: details)
    }

    private func recordLocked(_ name: String, details: [String: String]) {
        let event = DebugSessionEvent(timestamp: Date(), name: name, details: details)

        do {
            let data = try encoder.encode(event)
            let eventURL = directoryURL.appendingPathComponent("events.jsonl")

            if !fileManager.fileExists(atPath: eventURL.path) {
                fileManager.createFile(atPath: eventURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: eventURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
        } catch {
            // Debug logging must never break dictation.
        }
    }

    private func fileSize(at path: String) -> Int64? {
        (try? fileManager.attributesOfItem(atPath: path)[.size]) as? Int64
    }
}
