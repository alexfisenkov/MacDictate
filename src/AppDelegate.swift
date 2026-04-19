import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var appController: AppController?
    var downloaderWindowController: NSWindowController?
    var activeDownloader: ModelDownloader? // Жесткая ссылка (Критически важно для работы кнопки)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let modelsDir = ModelLocator.modelsDirectoryPath
        ModelLocator.ensureModelsDirectoryExists()

        var hasModel = ModelLocator.hasInstalledModel(in: modelsDir)
        if !hasModel {
            hasModel = ModelLocator.smartSearchExistingModels(destDir: modelsDir)
        }

        if !hasModel {
            showModelDownloader(modelsDir: modelsDir)
        } else {
            launchCoreApp()
        }
    }
    
    func showModelDownloader(modelsDir: String) {
        let downloader = ModelDownloader(modelsDir: modelsDir) { [weak self] success in
            if success {
                self?.downloaderWindowController?.close()
                self?.activeDownloader = nil // Освобождаем память после успешной скачки
                self?.launchCoreApp()
            } else {
                NSApp.terminate(nil)
            }
        }
        // Запоминаем скачиватель жестко, иначе кнопка "Цель" умрет
        self.activeDownloader = downloader
        
        let window = downloader.createWindow()
        let wc = NSWindowController(window: window)
        self.downloaderWindowController = wc
        wc.showWindow(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func launchCoreApp() {
        appController = AppController()
        appController?.start()
    }
}
