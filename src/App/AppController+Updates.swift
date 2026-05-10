import Cocoa

extension AppController {
    @objc func manualCheckForUpdates() {
        performUpdateCheck(isManual: true)
    }

    func performUpdateCheck(isManual: Bool) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        updateChecker.check(currentVersion: currentVersion) { result in
            DispatchQueue.main.async {
                switch result {
                case .newer(let updateInfo, let currentVersion):
                    self.showUpdateAvailableAlert(updateInfo, currentVersion: currentVersion)
                case .upToDate(let currentVersion):
                    if isManual {
                        self.showNoUpdatesAlert(currentVersion: currentVersion)
                    }
                case .unavailable(let detail):
                    if isManual {
                        self.showUpdateUnavailableAlert(detail: detail)
                    }
                }
            }
        }
    }

    private func showUpdateAvailableAlert(_ updateInfo: UpdateInfo, currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Доступно обновление MacDictate!"
        alert.informativeText = "Вышла версия \(updateInfo.version) (у вас \(currentVersion)).\n\nИзменения:\n\(updateInfo.releaseNotes)\n\nХотите скачать обновление прямо сейчас?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Скачать")
        alert.addButton(withTitle: "Позже")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let downloadURL = URL(string: updateInfo.releasePageURL) {
            NSWorkspace.shared.open(downloadURL)
        }
    }

    private func showNoUpdatesAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "У вас установлена последняя версия!"
        alert.informativeText = "Версия \(currentVersion) является самой актуальной. Обновлений не найдено."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "ОК")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showUpdateUnavailableAlert(detail: String) {
        let alert = NSAlert()
        alert.messageText = "Не удалось проверить обновления"
        alert.informativeText = "MacDictate не получил данные последнего релиза.\n\nПричина: \(detail)"
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
