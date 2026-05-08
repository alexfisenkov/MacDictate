import Cocoa
import ServiceManagement

struct AppMenuComponents {
    let menu: NSMenu
    let statusItem: NSMenuItem
    let licenseItem: NSMenuItem
    let diagnosticsItem: NSMenuItem
    let improveTextItem: NSMenuItem
    let accessibilityStateItem: NSMenuItem
    let microphoneStateItem: NSMenuItem
    let textImprovementStateItem: NSMenuItem
    let textImprovementToggleItem: NSMenuItem
    let textImprovementDownloadItem: NSMenuItem
}

enum MenuBuilder {
    static func build(for controller: AppController) -> AppMenuComponents {
        let menu = NSMenu()
        let statusItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        let licenseItem = NSMenuItem(title: "⏳ Лицензия: проверка...", action: #selector(AppController.openLicensePage), keyEquivalent: "")
        licenseItem.target = controller
        menu.addItem(licenseItem)

        let diagnosticsItem = NSMenuItem(title: "Диагностика: Инициализация...", action: nil, keyEquivalent: "")
        menu.addItem(diagnosticsItem)
        menu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: "📖 Инструкция", action: #selector(AppController.showInstructions), keyEquivalent: "")
        helpItem.target = controller
        menu.addItem(helpItem)

        let improveTextItem = NSMenuItem(title: "✨ Улучшить текст", action: #selector(AppController.improveTextFromClipboard), keyEquivalent: "")
        improveTextItem.target = controller
        menu.addItem(improveTextItem)
        menu.addItem(NSMenuItem.separator())

        let settingsMenuItem = NSMenuItem(title: "⚙️ Настройки", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()

        let accessibilityStateItem = NSMenuItem(title: "♿️ Универсальный доступ: проверка...", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(accessibilityStateItem)

        let microphoneStateItem = NSMenuItem(title: "🎤 Микрофон: проверка...", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(microphoneStateItem)
        settingsSubmenu.addItem(NSMenuItem.separator())

        let accessibilityAction = NSMenuItem(title: "Открыть настройки отслеживания", action: #selector(AppController.openAccessibilitySettings), keyEquivalent: "")
        accessibilityAction.target = controller
        settingsSubmenu.addItem(accessibilityAction)

        let microphoneAction = NSMenuItem(title: "Открыть настройки микрофона", action: #selector(AppController.openMicrophoneSettings), keyEquivalent: "")
        microphoneAction.target = controller
        settingsSubmenu.addItem(microphoneAction)
        settingsSubmenu.addItem(NSMenuItem.separator())

        let textImprovementStateItem = NSMenuItem(title: "✨ Улучшение текста: проверка...", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(textImprovementStateItem)

        let textImprovementToggleItem = NSMenuItem(title: "Улучшать текст после диктовки", action: #selector(AppController.toggleTextImprovement), keyEquivalent: "")
        textImprovementToggleItem.target = controller
        settingsSubmenu.addItem(textImprovementToggleItem)

        let textImprovementDownloadItem = NSMenuItem(title: "Скачать модель улучшения текста", action: #selector(AppController.downloadTextImprovementModel), keyEquivalent: "")
        textImprovementDownloadItem.target = controller
        settingsSubmenu.addItem(textImprovementDownloadItem)
        settingsSubmenu.addItem(NSMenuItem.separator())

        if #available(macOS 13.0, *) {
            let autoLaunchItem = NSMenuItem(title: "Запускать при включении Mac", action: #selector(AppController.toggleLaunchAtLogin), keyEquivalent: "")
            autoLaunchItem.target = controller
            autoLaunchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            settingsSubmenu.addItem(autoLaunchItem)
            settingsSubmenu.addItem(NSMenuItem.separator())
        }

        let restartItem = NSMenuItem(title: "🔄 Перезапустить программу", action: #selector(AppController.relaunchApp), keyEquivalent: "")
        restartItem.target = controller
        settingsSubmenu.addItem(restartItem)

        settingsSubmenu.addItem(NSMenuItem.separator())

        let uninstallItem = NSMenuItem(title: "🛑 Удалить MacDictate (Dangerous Zone)", action: #selector(AppController.confirmUninstall), keyEquivalent: "")
        uninstallItem.target = controller
        settingsSubmenu.addItem(uninstallItem)

        settingsMenuItem.submenu = settingsSubmenu
        menu.addItem(settingsMenuItem)

        menu.addItem(NSMenuItem.separator())
        let updateItem = NSMenuItem(title: "🔄 Проверить обновления", action: #selector(AppController.manualCheckForUpdates), keyEquivalent: "")
        updateItem.target = controller
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return AppMenuComponents(
            menu: menu,
            statusItem: statusItem,
            licenseItem: licenseItem,
            diagnosticsItem: diagnosticsItem,
            improveTextItem: improveTextItem,
            accessibilityStateItem: accessibilityStateItem,
            microphoneStateItem: microphoneStateItem,
            textImprovementStateItem: textImprovementStateItem,
            textImprovementToggleItem: textImprovementToggleItem,
            textImprovementDownloadItem: textImprovementDownloadItem
        )
    }
}
