import Cocoa

struct ModelDownloadConfiguration {
    let windowTitle: String
    let title: String
    let description: String
    let buttonTitle: String
    let statusReady: String
    let statusConnecting: String
    let statusFinished: String
    let destinationFilename: String
    let modelURL: URL
    let minimumBytes: Int64

    static let whisper = ModelDownloadConfiguration(
        windowTitle: "Настройка MacDictate",
        title: "Добро пожаловать в MacDictate!",
        description: "Для первого запуска необходимо скачать модель распознавания речи (Whisper). \n\n🔒 100% Локально и безопасно: ваши аудио обрабатываются только на процессоре вашего Mac и никуда не отправляются.",
        buttonTitle: "Скачать модель",
        statusReady: "Нажмите 'Скачать' для старта",
        statusConnecting: "Подключение к серверам HuggingFace...",
        statusFinished: "Загрузка завершена! Настройка окружения...",
        destinationFilename: "ggml-large-v3-turbo.bin",
        modelURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
        minimumBytes: 50_000_000
    )

    static let textImprovement = ModelDownloadConfiguration(
        windowTitle: "Улучшение текста MacDictate",
        title: "Скачать сбалансированную вторую нейросеть?",
        description: "MacDictate может локально улучшать текст после Whisper: исправлять пунктуацию, орфографию и лучше разбивать диктовку на смысловые абзацы и списки. \n\nМодель Qwen2.5-3B-Instruct Q4_K_M занимает около 2.1 GB и легче подходит для Mac с 16 GB памяти. Qwen 1.5B остается fallback-моделью.",
        buttonTitle: "Скачать Qwen 3B",
        statusReady: "Нажмите 'Скачать Qwen' для старта",
        statusConnecting: "Подключение к HuggingFace для загрузки Qwen 3B...",
        statusFinished: "Модель улучшения текста загружена.",
        destinationFilename: ModelLocator.textImprovementModelFilename,
        modelURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf")!,
        minimumBytes: ModelLocator.minimumTextImprovementModelBytes
    )
}

class ModelDownloader {
    let modelsDir: String
    let completion: (Bool) -> Void
    let configuration: ModelDownloadConfiguration
    
    var progressIndicator: NSProgressIndicator!
    var statusLabel: NSTextField!
    var downloadButton: NSButton!

    init(
        modelsDir: String,
        configuration: ModelDownloadConfiguration = .whisper,
        completion: @escaping (Bool) -> Void
    ) {
        self.modelsDir = modelsDir
        self.configuration = configuration
        self.completion = completion
    }
    
    func createWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 280),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.center()
        window.title = configuration.windowTitle
        
        // Визуальный контейнер
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 280))
        
        let titleLabel = NSTextField(labelWithString: configuration.title)
        titleLabel.frame = NSRect(x: 50, y: 220, width: 350, height: 30)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.alignment = .center
        view.addSubview(titleLabel)
        
        let infoLabel = NSTextField(wrappingLabelWithString: configuration.description)
        infoLabel.frame = NSRect(x: 40, y: 125, width: 370, height: 85)
        infoLabel.alignment = .center
        view.addSubview(infoLabel)
        
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 50, y: 95, width: 350, height: 20))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        view.addSubview(progressIndicator)
        
        statusLabel = NSTextField(labelWithString: configuration.statusReady)
        statusLabel.frame = NSRect(x: 50, y: 70, width: 350, height: 20)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        view.addSubview(statusLabel)
        
        downloadButton = NSButton(title: configuration.buttonTitle, target: self, action: #selector(startDownload))
        downloadButton.frame = NSRect(x: 150, y: 25, width: 150, height: 32)
        downloadButton.bezelStyle = .rounded
        view.addSubview(downloadButton)
        
        window.contentView = view
        return window
    }
    
    @objc func startDownload() {
        downloadButton.isEnabled = false
        statusLabel.stringValue = configuration.statusConnecting
        progressIndicator.isIndeterminate = true
        progressIndicator.startAnimation(nil)
        
        let destURL = URL(fileURLWithPath: modelsDir + "/" + configuration.destinationFilename)
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: DownloadDelegate(downloader: self, destURL: destURL), delegateQueue: OperationQueue.main)
        
        let task = session.downloadTask(with: configuration.modelURL)
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
            let size = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size]) as? Int64 ?? 0
            guard size >= downloader.configuration.minimumBytes else {
                downloader.statusLabel.stringValue = "Файл модели слишком маленький или поврежден. Проверьте интернет/VPN и попробуйте снова."
                downloader.downloadButton.isEnabled = true
                downloader.progressIndicator.doubleValue = 0
                return
            }

            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)
            downloader.statusLabel.stringValue = downloader.configuration.statusFinished
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.downloader.completion(true)
            }
        } catch {
            downloader.statusLabel.stringValue = "Не удалось сохранить модель. Проверьте доступ к домашней папке и свободное место."
            downloader.downloadButton.isEnabled = true
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            downloader.statusLabel.stringValue = "Ошибка загрузки: \(err.localizedDescription). Проверьте интернет/VPN и попробуйте снова."
            downloader.downloadButton.isEnabled = true
            downloader.progressIndicator.doubleValue = 0
        }
    }
}
