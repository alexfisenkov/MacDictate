import Cocoa

extension AppController {
    @objc func toggleTextImprovement(_ sender: NSMenuItem) {
        if TextImprovementSettings.isEnabled() {
            TextImprovementSettings.setEnabled(false)
            refreshTextImprovementMenuItems()
            refreshIdlePresentation()
            return
        }

        guard ensureTextImprovementReadyForInteractive(enableAfterDownload: true) else {
            refreshTextImprovementMenuItems()
            return
        }

        TextImprovementSettings.setEnabled(true)
        refreshTextImprovementMenuItems()
        refreshIdlePresentation()
    }

    @objc func downloadTextImprovementModel() {
        showTextImprovementModelDownloader(enableAfterDownload: false)
    }

    private func ensureTextImprovementReadyForInteractive(enableAfterDownload: Bool) -> Bool {
        guard textImprovementRunner.availableModelPath() != nil else {
            showTextImprovementModelDownloader(enableAfterDownload: enableAfterDownload)
            return false
        }

        guard textImprovementRunner.availableLlamaCliPath() != nil else {
            presentTextImprovementRuntimeAlert()
            return false
        }

        return true
    }

    private func showTextImprovementModelDownloader(enableAfterDownload: Bool) {
        ModelLocator.ensureModelsDirectoryExists()

        if let existingWindow = textImprovementWindowController?.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let downloader = ModelDownloader(
            modelsDir: ModelLocator.modelsDirectoryPath,
            configuration: .textImprovement
        ) { [weak self] success in
            guard let self else { return }

            self.textImprovementWindowController?.close()
            self.activeTextImprovementDownloader = nil

            if success, enableAfterDownload {
                if self.textImprovementRunner.availableLlamaCliPath() != nil {
                    TextImprovementSettings.setEnabled(true)
                    self.recordDiagnostic(nil)
                } else {
                    TextImprovementSettings.setEnabled(false)
                    self.presentTextImprovementRuntimeAlert()
                }
            }

            self.refreshTextImprovementMenuItems()
            self.refreshIdlePresentation()
        }

        activeTextImprovementDownloader = downloader
        let window = downloader.createWindow()
        let windowController = NSWindowController(window: window)
        textImprovementWindowController = windowController
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentTextImprovementRuntimeAlert() {
        presentTextImprovementAlert(
            title: "Нужен llama.cpp",
            message: "Для второй локальной нейросети установите llama.cpp: brew install llama.cpp. После этого MacDictate сможет запускать Qwen локально."
        )
    }

    private func presentTextImprovementAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "ОК")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
