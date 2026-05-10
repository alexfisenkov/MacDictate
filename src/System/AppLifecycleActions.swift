import Cocoa

enum AppLifecycleActions {
    static func relaunchApp(appPath: String = Bundle.main.bundlePath) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "sleep 1 && /usr/bin/open '\(appPath)'"]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    static func uninstallApp(
        appPath: String = Bundle.main.bundlePath,
        modelsPath: String = FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate"
    ) {
        try? FileManager.default.removeItem(atPath: modelsPath)

        let task = Process()
        task.launchPath = "/bin/bash"
        let bashCommand = """
        sleep 1
        rm -rf '\(appPath)'
        tccutil reset Accessibility com.alexfisenkov.macdictate || true
        tccutil reset Microphone com.alexfisenkov.macdictate || true
        """
        task.arguments = ["-c", bashCommand]
        try? task.run()

        NSApplication.shared.terminate(nil)
    }
}
