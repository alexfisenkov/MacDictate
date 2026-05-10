import Cocoa

extension AppController {
    @objc func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "Удалить MacDictate?"
        alert.informativeText = "Вы уверены? Это действие безвозвратно удалит саму программу и сотрет нейросеть Whisper (~1.6 ГБ) с вашего диска."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Удалить полностью")
        alert.addButton(withTitle: "Отмена")

        if alert.runModal() == .alertFirstButtonReturn {
            AppLifecycleActions.uninstallApp()
        }
    }

    @objc func showInstructions() {
        let alert = NSAlert()
        alert.messageText = "Как использовать MacDictate"

        var info = """
        • Двойное нажатие Option (⌥): Начать запись.
        • Одинарное нажатие Option (⌥): Остановить запись.

        Программа распознаёт речь абсолютно без интернета. Текст вставляется туда, где стоит ваш курсор.

        """

        if !AXIsProcessTrusted() {
            info += "\n⚠️ ВАЖНО: У вас не выданы права на отслеживание клавиш. Если при выдаче прав галочка «залипла» — обязательно выделите старую версию MacDictate, нажмите минус (-) внизу списка и добавьте её заново плюсом (+)."
        }

        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Понятно")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func relaunchApp() {
        AppLifecycleActions.relaunchApp()
    }

    @available(macOS 13.0, *)
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if LaunchAtLoginService.isEnabled {
                try LaunchAtLoginService.setEnabled(false)
                sender.state = .off
            } else {
                try LaunchAtLoginService.setEnabled(true)
                sender.state = .on

                let alert = NSAlert()
                alert.messageText = "MacDictate добавлен в Автозагрузку!"
                alert.informativeText = "Теперь программа будет запускаться вместе с вашим Mac. Вы можете проверить это в Настройки -> Основные -> Элементы входа."
                alert.alertStyle = .informational
                alert.runModal()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Ошибка Автозагрузки"
            alert.informativeText = "macOS заблокировала фоновый запуск. Убедитесь, что MacDictate находится в папке 'Программы' (Applications). Ошибка: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func handleVersionUpgrade() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let versionKey = "\(currentVersion)_\(currentBuild)"
        UserDefaults.standard.set(versionKey, forKey: "LastLaunchedVersion")
    }

    @objc func openLicensePage() {
        if let url = licenseService.purchaseURL() {
            NSWorkspace.shared.open(url)
        }
    }
}
