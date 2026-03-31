import Cocoa

class ModelDownloader {
    let modelsDir: String
    let completion: (Bool) -> Void
    
    var progressIndicator: NSProgressIndicator!
    var statusLabel: NSTextField!
    var downloadButton: NSButton!
    
    // Модель по умолчанию
    let modelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
    
    init(modelsDir: String, completion: @escaping (Bool) -> Void) {
        self.modelsDir = modelsDir
        self.completion = completion
    }
    
    func createWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.center()
        window.title = "Настройка MacDictate"
        
        // Визуальный контейнер
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 250))
        
        let titleLabel = NSTextField(labelWithString: "Добро пожаловать в MacDictate!")
        titleLabel.frame = NSRect(x: 50, y: 190, width: 350, height: 30)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.alignment = .center
        view.addSubview(titleLabel)
        
        let infoText = "Для первого запуска необходимо скачать модель распознавания речи (Whisper). \n\n🔒 100% Локально и безопасно: ваши аудио обрабатываются только на процессоре вашего Mac и никуда не отправляются."
        let infoLabel = NSTextField(wrappingLabelWithString: infoText)
        infoLabel.frame = NSRect(x: 40, y: 120, width: 370, height: 60)
        infoLabel.alignment = .center
        view.addSubview(infoLabel)
        
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 50, y: 90, width: 350, height: 20))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        view.addSubview(progressIndicator)
        
        statusLabel = NSTextField(labelWithString: "Нажмите 'Скачать' для старта")
        statusLabel.frame = NSRect(x: 50, y: 65, width: 350, height: 20)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        view.addSubview(statusLabel)
        
        downloadButton = NSButton(title: "Скачать модель", target: self, action: #selector(startDownload))
        downloadButton.frame = NSRect(x: 150, y: 20, width: 150, height: 32)
        downloadButton.bezelStyle = .rounded
        view.addSubview(downloadButton)
        
        window.contentView = view
        return window
    }
    
    @objc func startDownload() {
        downloadButton.isEnabled = false
        statusLabel.stringValue = "Подключение к серверам HuggingFace..."
        progressIndicator.isIndeterminate = true
        progressIndicator.startAnimation(nil)
        
        let destURL = URL(fileURLWithPath: modelsDir + "/ggml-large-v3-turbo.bin")
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: DownloadDelegate(downloader: self, destURL: destURL), delegateQueue: OperationQueue.main)
        
        let task = session.downloadTask(with: modelURL)
        task.resume()
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let downloader: ModelDownloader
    let destURL: URL
    
    init(downloader: ModelDownloader, destURL: URL) {
        self.downloader = downloader
        self.destURL = destURL
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if downloader.progressIndicator.isIndeterminate {
            downloader.progressIndicator.isIndeterminate = false
            downloader.progressIndicator.stopAnimation(nil)
        }
        
        // Предотвращение деления на ноль, если размер неизвестен
        if totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100.0
            downloader.progressIndicator.doubleValue = progress
            let downloadedMB = String(format: "%.1f", Double(totalBytesWritten) / 1024.0 / 1024.0)
            let totalMB = String(format: "%.1f", Double(totalBytesExpectedToWrite) / 1024.0 / 1024.0)
            downloader.statusLabel.stringValue = "Загрузка: \(downloadedMB) MB / \(totalMB) MB"
        } else {
            let downloadedMB = String(format: "%.1f", Double(totalBytesWritten) / 1024.0 / 1024.0)
            downloader.statusLabel.stringValue = "Загружено: \(downloadedMB) MB"
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)
            downloader.statusLabel.stringValue = "Загрузка завершена! Настройка окружения..."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.downloader.completion(true)
            }
        } catch {
            downloader.statusLabel.stringValue = "Ошибка сохранения. Перезапустите."
            downloader.downloadButton.isEnabled = true
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            downloader.statusLabel.stringValue = "Ошибка: \(err.localizedDescription)"
            downloader.downloadButton.isEnabled = true
            downloader.progressIndicator.doubleValue = 0
        }
    }
}
