import Foundation

enum ModelLocator {
    static var modelsDirectoryPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate/models"
    }

    static func ensureModelsDirectoryExists() {
        try? FileManager.default.createDirectory(
            atPath: modelsDirectoryPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    static func hasInstalledModel(in directory: String = modelsDirectoryPath) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return false
        }

        return files.contains { $0.hasSuffix(".bin") }
    }

    static func bestAvailableModelPath(in directory: String = modelsDirectoryPath) -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        let binFiles = files.filter { $0.hasSuffix(".bin") }
        guard !binFiles.isEmpty else { return nil }

        let sorted = binFiles.sorted { lhs, rhs in
            let lhsPath = directory + "/" + lhs
            let rhsPath = directory + "/" + rhs
            let lhsSize = (try? FileManager.default.attributesOfItem(atPath: lhsPath)[.size] as? Int) ?? 0
            let rhsSize = (try? FileManager.default.attributesOfItem(atPath: rhsPath)[.size] as? Int) ?? 0
            return lhsSize > rhsSize
        }

        guard let bestModel = sorted.first else { return nil }
        return directory + "/" + bestModel
    }

    static func smartSearchExistingModels(destDir: String = modelsDirectoryPath) -> Bool {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        let knownPaths = [
            "/opt/homebrew/share/whisper.cpp/models",
            "/usr/local/share/whisper.cpp/models",
            homeDir + "/.cache/whisper",
            homeDir + "/Library/Application Support/whisper.cpp/models",
            homeDir + "/Downloads"
        ]

        for path in knownPaths {
            guard let files = try? fileManager.contentsOfDirectory(atPath: path) else {
                continue
            }

            let binFiles = files.filter { $0.hasSuffix(".bin") }
            for file in binFiles {
                let fullPath = path + "/" + file
                if let size = (try? fileManager.attributesOfItem(atPath: fullPath)[.size]) as? Int64,
                   size > 50_000_000 {
                    do {
                        try fileManager.copyItem(atPath: fullPath, toPath: destDir + "/" + file)
                        return true
                    } catch {
                        continue
                    }
                }
            }
        }

        return false
    }
}
