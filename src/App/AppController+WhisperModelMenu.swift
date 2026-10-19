import Cocoa

extension AppController {
    @objc func toggleMaximumAccuracyWhisper(_ sender: NSMenuItem) {
        if WhisperModelSettings.currentMode() == .maximumAccuracy {
            WhisperModelSettings.setMode(.balanced)
            refreshWhisperModelMenuItems()
            refreshIdlePresentation()
            return
        }

        guard ensureMaximumAccuracyWhisperReady(enableAfterDownload: true) else {
            refreshWhisperModelMenuItems()
            return
        }

        WhisperModelSettings.setMode(.maximumAccuracy)
        refreshWhisperModelMenuItems()
        refreshIdlePresentation()
    }

    @objc func downloadMaximumAccuracyWhisperModel() {
        showMaximumAccuracyWhisperDownloader(enableAfterDownload: false)
    }

    private func ensureMaximumAccuracyWhisperReady(enableAfterDownload: Bool) -> Bool {
        guard ModelLocator.hasInstalledMaximumAccuracyWhisperModel() else {
            showMaximumAccuracyWhisperDownloader(enableAfterDownload: enableAfterDownload)
            return false
        }

        return true
    }

    private func showMaximumAccuracyWhisperDownloader(enableAfterDownload: Bool) {
        ModelLocator.ensureModelsDirectoryExists()

        if let existingWindow = whisperModelWindowController?.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let downloader = ModelDownloader(
            modelsDir: ModelLocator.modelsDirectoryPath,
            configuration: .maximumAccuracyWhisper
        ) { [weak self] success in
            guard let self else { return }

            self.whisperModelWindowController?.close()
            self.activeWhisperModelDownloader = nil

            if success, enableAfterDownload {
                WhisperModelSettings.setMode(.maximumAccuracy)
                self.recordDiagnostic(nil)
            }

            self.refreshWhisperModelMenuItems()
            self.refreshIdlePresentation()
        }

        activeWhisperModelDownloader = downloader
        let window = downloader.createWindow()
        let windowController = NSWindowController(window: window)
        whisperModelWindowController = windowController
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
