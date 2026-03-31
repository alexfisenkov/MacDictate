import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var appController: AppController?
    var downloaderWindowController: NSWindowController?
    var activeDownloader: ModelDownloader? // Жесткая ссылка (Критически важно для работы кнопки)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let fileManager = FileManager.default
        let modelsDir = fileManager.homeDirectoryForCurrentUser.path + "/.macdictate/models"
        
        // Создаем папку, если ее нет
        try? fileManager.createDirectory(atPath: modelsDir, withIntermediateDirectories: true, attributes: nil)
        
        // Проверяем наличие любой модели в ~/.macdictate
        var hasModel = false
        if let files = try? fileManager.contentsOfDirectory(atPath: modelsDir) {
            hasModel = files.contains { $0.hasSuffix(".bin") }
        }
        
        // Магия: Умный поиск по системе!
        if !hasModel {
            hasModel = smartSearchExistingModels(destDir: modelsDir)
        }
        
        if !hasModel {
            showModelDownloader(modelsDir: modelsDir)
        } else {
            launchCoreApp()
        }
    }
    
    func smartSearchExistingModels(destDir: String) -> Bool {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        let knownPaths = [
            "/opt/homebrew/share/whisper.cpp/models",
            "/usr/local/share/whisper.cpp/models",
            homeDir + "/.cache/whisper",
            homeDir + "/Library/Application Support/whisper.cpp/models",
            homeDir + "/Downloads"
        ]
        
        for p in knownPaths {
            guard let files = try? fileManager.contentsOfDirectory(atPath: p) else { continue }
            let bins = files.filter { $0.hasSuffix(".bin") }
            for b in bins {
                let fullPath = p + "/" + b
                if let size = (try? fileManager.attributesOfItem(atPath: fullPath)[.size]) as? Int64, size > 50_000_000 {
                    do {
                        try fileManager.copyItem(atPath: fullPath, toPath: destDir + "/" + b)
                        return true
                    } catch {
                        continue
                    }
                }
            }
        }
        return false
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
