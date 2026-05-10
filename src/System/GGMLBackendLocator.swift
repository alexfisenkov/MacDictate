import Foundation
import Darwin

enum GGMLBackendLocator {
    static func bundledBackendPath(
        forRuntimePath runtimePath: String,
        preferredBackendFilenames: [String] = appleSiliconCPUBackendPreference()
    ) -> String? {
        guard let resourcesURL = resourcesURL(forRuntimePath: runtimePath) else {
            return nil
        }

        return bundledBackendPath(
            resourcesURL: resourcesURL,
            preferredBackendFilenames: preferredBackendFilenames
        )
    }

    static func bundledBackendPath(
        resourcesURL: URL,
        preferredBackendFilenames: [String] = appleSiliconCPUBackendPreference()
    ) -> String? {
        let backendDirectoryURL = resourcesURL.appendingPathComponent("libexec/ggml", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: backendDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        for filename in preferredBackendFilenames {
            let candidate = backendDirectoryURL.appendingPathComponent(filename)
            if FileManager.default.isReadableFile(atPath: candidate.path) {
                return candidate.path
            }
        }

        let fallbackCandidates = (try? FileManager.default.contentsOfDirectory(
            at: backendDirectoryURL,
            includingPropertiesForKeys: nil
        )) ?? []

        return fallbackCandidates
            .filter { $0.lastPathComponent.hasPrefix("libggml-") && $0.pathExtension == "so" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first?
            .path
    }

    static func appleSiliconCPUBackendPreference() -> [String] {
        let brand = cpuBrandString().lowercased()
        if brand.contains("m4") {
            return [
                "libggml-cpu-apple_m4.so",
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so",
                "libggml-metal.so",
                "libggml-blas.so"
            ]
        }

        if brand.contains("m2") || brand.contains("m3") {
            return [
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so",
                "libggml-cpu-apple_m4.so",
                "libggml-metal.so",
                "libggml-blas.so"
            ]
        }

        return [
            "libggml-cpu-apple_m1.so",
            "libggml-cpu-apple_m2_m3.so",
            "libggml-cpu-apple_m4.so",
            "libggml-metal.so",
            "libggml-blas.so"
        ]
    }

    private static func resourcesURL(forRuntimePath runtimePath: String) -> URL? {
        let runtimeURL = URL(fileURLWithPath: runtimePath)
        let resourcesURL = runtimeURL.deletingLastPathComponent().deletingLastPathComponent()
        guard resourcesURL.lastPathComponent == "Resources" else {
            return nil
        }
        return resourcesURL
    }

    private static func cpuBrandString() -> String {
        let key = "machdep.cpu.brand_string"
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else {
            return ""
        }

        return String(cString: buffer)
    }
}
