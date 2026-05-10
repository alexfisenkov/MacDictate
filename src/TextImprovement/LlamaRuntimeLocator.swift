import Foundation

enum LlamaRuntimeLocator {
    private static let bundledExecutableNames = [
        "llama-completion",
        "llama-cli"
    ]

    private static let defaultFallbackPaths = [
        "/opt/homebrew/bin/llama-completion",
        "/opt/homebrew/bin/llama-cli",
        "/usr/local/bin/llama-completion",
        "/usr/local/bin/llama-cli"
    ]

    static func findRuntimePath(in bundle: Bundle) -> String? {
        findRuntimePath(resourcePath: bundle.resourcePath)
    }

    static func findRuntimePath(
        resourcePath: String?,
        fallbackPaths: [String] = defaultFallbackPaths,
        fileManager: FileManager = .default
    ) -> String? {
        if let resourcePath {
            for executableName in bundledExecutableNames {
                let candidate = resourcePath + "/bin/" + executableName
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        for candidate in fallbackPaths where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }
}
