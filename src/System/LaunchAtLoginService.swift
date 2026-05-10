import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    @available(macOS 13.0, *)
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @available(macOS 13.0, *)
    static func setEnabled(_ isEnabled: Bool, appPath: String = Bundle.main.bundlePath) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
            addLegacyLoginItem(appPath: appPath)
        } else {
            try SMAppService.mainApp.unregister()
            removeLegacyLoginItem()
        }
    }

    private static func addLegacyLoginItem(appPath: String) {
        let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(appPath)\", hidden:false, name:\"MacDictate\"}"
        runAppleScript(script)
    }

    private static func removeLegacyLoginItem() {
        let script = "tell application \"System Events\" to delete login item \"MacDictate\""
        runAppleScript(script)
    }

    private static func runAppleScript(_ script: String) {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }
}
