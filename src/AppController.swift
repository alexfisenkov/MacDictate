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
        handleVersionUpgrade()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🎙️"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let helpItem = NSMenuItem(title: "📖 Инструкция", action: #selector(showInstructions), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        menu.addItem(NSMenuItem.separator())
        
        // --- Подменю: Настройки ---
        let settingsMenuItem = NSMenuItem(title: "⚙️ Настройки", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()
        
        let emojiStatus = NSMenuItem(title: AXIsProcessTrusted() ? "✅ Права получены" : "❌ Права отсутствуют", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(emojiStatus)
        
        let accessibilityStatus = NSMenuItem(title: "Разрешить отслеживание", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityStatus.target = self
        settingsSubmenu.addItem(accessibilityStatus)
        settingsSubmenu.addItem(NSMenuItem.separator())
        
        if #available(macOS 13.0, *) {
            let autoLaunchItem = NSMenuItem(title: "Запускать при включении Mac", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            autoLaunchItem.target = self
            autoLaunchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            settingsSubmenu.addItem(autoLaunchItem)
            settingsSubmenu.addItem(NSMenuItem.separator())
        }
        
        let restartItem = NSMenuItem(title: "🔄 Перезапустить программу", action: #selector(relaunchApp), keyEquivalent: "")
        restartItem.target = self
        settingsSubmenu.addItem(restartItem)
        
        settingsSubmenu.addItem(NSMenuItem.separator())
        
        let uninstallItem = NSMenuItem(title: "🛑 Удалить MacDictate (Dangerous Zone)", action: #selector(confirmUninstall), keyEquivalent: "")
        uninstallItem.target = self
        settingsSubmenu.addItem(uninstallItem)
        
        settingsMenuItem.submenu = settingsSubmenu
        menu.addItem(settingsMenuItem)
        // -----------------------------
        
        menu.addItem(NSMenuItem.separator())
        let updateItem = NSMenuItem(title: "🔄 Проверить обновления", action: #selector(manualCheckForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        checkPermissions()
        setupHotkeys()
        
        // Автоматическая (тихая) проверка при запуске
        performUpdateCheck(isManual: false)
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
    
    @objc func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
        let alert = NSAlert()
        alert.messageText = "Настройки Отслеживания (Универсальный доступ)"
        alert.informativeText = "Поставьте галочку напротив MacDictate.\n\n❗️ СИСТЕМНЫЙ БАГ MACOS: Если программа не реагирует на галочку (например, после обновления версий) — вам НУЖНО физически выделить MacDictate мышкой, нажать минус (-) в самом низу списка, а затем нажать плюс (+) и добавить программу заново из папки Программы."
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        
        // Запускаем таймер, если права еще не даны
        if !AXIsProcessTrusted() {
            startPermissionPolling()
        }
        
        alert.runModal()
    }
    
    func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Требуется Универсальный доступ"
        alert.informativeText = "MacDictate нужно разрешение для отслеживания двойного нажатия системной клавиши Option (Alt).\n\nНажмите «Открыть Настройки» и поставьте галочку. \n\n❗️ ЕСЛИ ОБНОВЛЯЕТЕ ВЕРСИЮ: Старая галочка может \"залипать\". Выделите её мышкой, нажмите минус (-) внизу списка, а затем добавьте новую программу плюсом (+)."
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
    
    @objc func relaunchApp() {
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
    
    func handleVersionUpgrade() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let versionKey = "\(currentVersion)_\(currentBuild)"
        // Из-за ограничений безопасности (SIP) Apple запрещает приложению самому
        // сбрасывать свои же права TCC через bash без прав администратора, поэтому
        // мы больше не пытаемся делать tccutil reset. Пользователю нужно использовать минус и плюс вручную.
        UserDefaults.standard.set(versionKey, forKey: "LastLaunchedVersion")
    }
    
    @objc func manualCheckForUpdates() {
        performUpdateCheck(isManual: true)
    }
    
    func performUpdateCheck(isManual: Bool) {
        // Запрос к официальному API GitHub Releases
        let updateUrlString = "https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest"
        
        guard let url = URL(string: updateUrlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Проверка на 404 (приватный репозиторий) или сетевую ошибку
            guard let data = data, error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if isManual {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "ОШИБКА: Репозиторий скрыт (Private) или нет сети"
                        alert.informativeText = "Не удалось проверить обновления. Если репозиторий на GitHub всё ещё Private (Скрытый), обновления будут возвращать ошибку 404. Сделайте его Public в настройках."
                        alert.alertStyle = .warning
                        NSApp.activate(ignoringOtherApps: true)
                        alert.runModal()
                    }
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   var fetchedVersion = json["tag_name"] as? String,
                   let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let releasePageUrl = json["html_url"] as? String,
                   let releaseNotes = json["body"] as? String {
                    
                    // Убираем букву 'v' из тега (например, 'v1.4' -> '1.4')
                    if fetchedVersion.hasPrefix("v") {
                        fetchedVersion.removeFirst()
                    }
                    
                    if fetchedVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Доступно обновление MacDictate!"
                            alert.informativeText = "Вышла версия \(fetchedVersion) (у вас \(currentVersion)).\n\nИзменения:\n\(releaseNotes)\n\nХотите скачать обновление прямо сейчас?"
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "Скачать")
                            alert.addButton(withTitle: "Позже")
                            NSApp.activate(ignoringOtherApps: true)
                            if alert.runModal() == .alertFirstButtonReturn {
                                if let downloadUrl = URL(string: releasePageUrl) {
                                    NSWorkspace.shared.open(downloadUrl)
                                }
                            }
                        }
                    } else {
                        // Если проверка ручная и обновлений нет
                        if isManual {
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "У вас установлена последняя версия!"
                                alert.informativeText = "Версия \(currentVersion) является самой актуальной. Обновлений не найдено."
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "ОК")
                                NSApp.activate(ignoringOtherApps: true)
                                alert.runModal()
                            }
                        }
                    }
                }
            } catch {
                if isManual {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Ошибка"
                        alert.informativeText = "Не удалось обработать данные об обновлениях."
                        alert.alertStyle = .warning
                        NSApp.activate(ignoringOtherApps: true)
                        alert.runModal()
                    }
                }
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
        
        NSSound(named: "Tink")?.play()
        
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
