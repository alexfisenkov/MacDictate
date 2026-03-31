import Cocoa
import AVFoundation
import ServiceManagement

class AppController {
    
    var statusItem: NSStatusItem!
    var audioRecorder: AVAudioRecorder?
    var isRecording = false
    var isProcessing = false
    var lastOptionPressTime: TimeInterval = 0
    let tempWavPath = "/tmp/mac_dictate_dist.wav"
    
    // Поиск динамической модели
    func getLatestModelPath() -> String? {
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate/models"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: modelsDir) else { return nil }
        
        let binFiles = files.filter { $0.hasSuffix(".bin") }
        if binFiles.isEmpty { return nil }
        
        // Вернем самый большой по размеру файл (скорее всего это самая мощная скачанная модель)
        let sorted = binFiles.sorted { f1, f2 in
            let path1 = modelsDir + "/" + f1
            let path2 = modelsDir + "/" + f2
            let size1 = (try? FileManager.default.attributesOfItem(atPath: path1)[.size] as? Int) ?? 0
            let size2 = (try? FileManager.default.attributesOfItem(atPath: path2)[.size] as? Int) ?? 0
            return size1 > size2
        }
        
        return modelsDir + "/" + sorted.first!
    }
    
    // Поиск встроенного whisper-cli
    func getWhisperCliPath() -> String {
        guard let resourcePath = Bundle.main.resourcePath else { return "/opt/homebrew/bin/whisper-cli" }
        let embeddedPath = resourcePath + "/bin/whisper-cli"
        if FileManager.default.fileExists(atPath: embeddedPath) {
            return embeddedPath
        }
        return "/opt/homebrew/bin/whisper-cli"
    }

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🎙️"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        if #available(macOS 13.0, *) {
            let autoLaunchItem = NSMenuItem(title: "Запускать при включении Mac", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            autoLaunchItem.target = self
            autoLaunchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(autoLaunchItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem(title: "Quit MacDictate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(NSMenuItem.separator())
        let uninstallItem = NSMenuItem(title: "🗑 Удалить MacDictate полностью", action: #selector(confirmUninstall), keyEquivalent: "")
        uninstallItem.target = self
        menu.addItem(uninstallItem)
        statusItem.menu = menu
        
        checkPermissions()
        setupHotkeys()
        checkForUpdates()
    }
    
    @objc func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "Удалить MacDictate?"
        alert.informativeText = "Вы уверены? Это действие безвозвратно удалит саму программу и сотрет нейросеть Whisper (~1.6 ГБ) с вашего диска."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Удалить полностью")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            executeSelfDestruct()
        }
    }
    
    func executeSelfDestruct() {
        // 1. Удаляем тяжелую папку с моделями
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate"
        try? FileManager.default.removeItem(atPath: modelsDir)
        
        // 2. Получаем пусть к самому приложению .app
        let appPath = Bundle.main.bundlePath
        
        // 3. Запускаем "мину замедленного действия" в консоли
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
        
        // 4. Мгновенно убиваем текущий процесс, чтобы bash смог стереть файлы
        NSApplication.shared.terminate(nil)
    }
    
    var permissionTimer: Timer?

    func checkPermissions() {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted { print("Microphone access denied!") }
            }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted { print("Microphone access denied!") }
            }
        }
        
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            setStatus("Needs Accessibility", icon: "⚠️")
            promptAccessibility()
        }
    }
    
    func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Требуется Универсальный доступ"
        alert.informativeText = "MacDictate нужно разрешение для отслеживания двойного нажатия системной клавиши Option (Alt).\n\nНажмите «Открыть Настройки», поставьте галочку напротив MacDictate. Мы автоматически перезапустим приложение, когда вы это сделаете!"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть Настройки")
        alert.addButton(withTitle: "Позже")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Открыть системные настройки Privacy -> Accessibility
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            
            // Запускаем невидимый таймер, который ждет, пока вы не поставите галочку
            startPermissionPolling()
        }
    }
    
    func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() {
                t.invalidate()
                self?.promptRestart()
            }
        }
    }
    
    func promptRestart() {
        let alert = NSAlert()
        alert.messageText = "Разрешение получено! 🎉"
        alert.informativeText = "Спасибо! Чтобы горячие клавиши заработали, программе нужно перезагрузиться."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Перезагрузить")
        
        if alert.runModal() == .alertFirstButtonReturn {
            self.relaunchApp()
        }
    }
    
    func relaunchApp() {
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "sleep 1 && /usr/bin/open '\(appPath)'"]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
    
    @available(macOS 13.0, *)
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let appPath = Bundle.main.bundlePath
        
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
                
                // Fallback delete via AppleScript
                let script = "tell application \"System Events\" to delete login item \"MacDictate\""
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = ["-e", script]
                try? task.run()
                
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
                
                // Fallback add via AppleScript to guarantee it appears in the visual list!
                let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(appPath)\", hidden:false, name:\"MacDictate\"}"
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = ["-e", script]
                try? task.run()
                
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
    
    func checkForUpdates() {
        // Мы используем публичный Gist или сервер для проверки версий.
        // Замените этот URL на ваш реальный публичный источник!
        let updateUrlString = "https://gist.githubusercontent.com/alexfisenkov/dbd7b27fc29b4661000/raw/version.json" 
        
        guard let url = URL(string: updateUrlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let fetchedVersion = json["version"] as? String,
                   let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let downloadUrlStr = json["download_url"] as? String,
                   let releaseNotes = json["release_notes"] as? String {
                    
                    // Самое банальное сравнение строк (1.2 > 1.1)
                    if fetchedVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Доступно обновление MacDictate!"
                            alert.informativeText = "Вышла версия \(fetchedVersion) (у вас \(currentVersion)).\n\nИзменения:\n\(releaseNotes)\n\nХотите скачать обновление прямо сейчас?"
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "Скачать")
                            alert.addButton(withTitle: "Позже")
                            
                            if alert.runModal() == .alertFirstButtonReturn {
                                if let downloadUrl = URL(string: downloadUrlStr) {
                                    NSWorkspace.shared.open(downloadUrl)
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Failed to parse update json: \(error)")
            }
        }
        task.resume()
    }
    
    func setStatus(_ text: String, icon: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.title = icon
            self.statusItem.menu?.items[0].title = "Status: \(text)"
        }
    }
    
    func setupHotkeys() {
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            
            // keyCode 58 - Option (Alt)
            if event.keyCode == 58 {
                let isPressedDown = event.modifierFlags.contains(.option)
                
                if isPressedDown {
                    let now = Date().timeIntervalSince1970
                    
                    if self.isRecording {
                        self.stopRecordingAndProcess()
                    } else if !self.isProcessing {
                        if now - self.lastOptionPressTime < 0.4 {
                            self.startRecording()
                        }
                    }
                    self.lastOptionPressTime = now
                }
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        let audioFilename = URL(fileURLWithPath: tempWavPath)
        
        // Для Whisper нужен 16kHz PCM
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            setStatus("Listening...", icon: "🔴")
            NSSound(named: "Blow")?.play()
            
        } catch {
            setStatus("Error recording", icon: "⚠️")
        }
    }
    
    func stopRecordingAndProcess() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        isProcessing = true
        
        setStatus("Transcribing...", icon: "⏳")
        NSSound(named: "Pop")?.play()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let output = self.runWhisper()
            
            DispatchQueue.main.async {
                self.setStatus("Ready", icon: "🎙️")
                self.isProcessing = false
                
                if let text = output {
                    let cleaned = self.cleanWhisperOutput(text)
                    if !cleaned.isEmpty {
                        self.pasteText(cleaned)
                    }
                }
            }
        }
    }
    
    func runWhisper() -> String? {
        guard let modelPath = getLatestModelPath() else {
            DispatchQueue.main.async { self.setStatus("Model Not Found", icon: "⚠️") }
            return nil
        }
        
        let whisperCli = getWhisperCliPath()
        
        let task = Process()
        task.launchPath = whisperCli
        // -nt = no timestamps, -otxt = output txt
        task.arguments = ["-m", modelPath, "-f", tempWavPath, "-l", "ru", "-nt", "-otxt"]
        
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let txtPath = tempWavPath + ".txt"
            if FileManager.default.fileExists(atPath: txtPath) {
                let transcribedResult = try String(contentsOfFile: txtPath, encoding: .utf8)
                
                try? FileManager.default.removeItem(atPath: txtPath)
                try? FileManager.default.removeItem(atPath: tempWavPath)
                
                return transcribedResult
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func cleanWhisperOutput(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        str = str.replacingOccurrences(of: "[БЕЗ ЗВУКА]", with: "")
        str = str.replacingOccurrences(of: "[без звука]", with: "")
        str = str.replacingOccurrences(of: "[ШУМ]", with: "")
        str = str.replacingOccurrences(of: "(БЕЗ ЗВУКА)", with: "")
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return str
    }
    
    func pasteText(_ input: String) {
        if input.isEmpty { return }
        let text = input + " "
        
        let pb = NSPasteboard.general
        let oldString = pb.string(forType: .string)
        
        pb.clearContents()
        pb.setString(text, forType: .string)
        
        simulatePaste()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let old = oldString {
                pb.clearContents()
                pb.setString(old, forType: .string)
            }
        }
    }
    
    func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        if let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
           let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
            
            vKeyDown.flags = .maskCommand
            vKeyUp.flags = .maskCommand
            
            usleep(20_000)
            vKeyDown.post(tap: .cghidEventTap)
            usleep(10_000)
            vKeyUp.post(tap: .cghidEventTap)
        }
    }
}
