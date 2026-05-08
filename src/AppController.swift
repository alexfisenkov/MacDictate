import Cocoa
import ServiceManagement

final class AppController: NSObject {
    private let licenseService = LicenseService()
    private let whisperRunner = WhisperRunner()
    private let textImprovementRunner = TextImprovementRunner()
    private lazy var diagnostics = EnvironmentDiagnostics(whisperRunner: whisperRunner)
    private let recordingService = RecordingService()
    private let pasteService = PasteService()

    private var statusItem: NSStatusItem!
    private var menuComponents: AppMenuComponents!
    private var hotkeyMonitor: HotkeyMonitor?
    private var permissionTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var textImprovementWindowController: NSWindowController?
    private var activeTextImprovementDownloader: ModelDownloader?

    private var runtimeDiagnostic: RuntimeDiagnostic?
    private var isProcessing = false
    private var lastBlockedAlertKey: String?
    private var lastBlockedAlertAt: Date = .distantPast

    private let blockedAlertThrottle: TimeInterval = 15

    deinit {
        permissionTimer?.invalidate()
        hotkeyMonitor?.stop()
        licenseService.stop()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func start() {
        handleVersionUpgrade()
        buildMenu()
        bindServices()

        licenseService.restoreCachedState()
        refreshPresentation()

        observeWake()
        checkPermissions()
        setupHotkeys()
        licenseService.startRefreshLoop()

        performUpdateCheck(isManual: false)
        licenseService.checkStatus(promoteCheckingState: !licenseService.state.allowsDictation)
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎙️"

        menuComponents = MenuBuilder.build(for: self)
        statusItem.menu = menuComponents.menu
    }

    private func bindServices() {
        licenseService.onChange = { [weak self] in
            self?.refreshPresentation()
        }
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.licenseService.handleWake()
        }
    }

    private var activeRuntimeDiagnostic: RuntimeDiagnostic? {
        runtimeDiagnostic ?? licenseService.runtimeDiagnostic
    }

    private func refreshPresentation() {
        licenseService.normalizeStateIfNeeded()
        refreshLicenseMenuItem()
        refreshPermissionMenuItems()
        refreshTextImprovementMenuItems()
        refreshDiagnosticsMenuItem()
        refreshIdlePresentation()
    }

    private func refreshLicenseMenuItem() {
        menuComponents.licenseItem.title = StatusPresentation.licenseMenuTitle(
            state: licenseService.state,
            machineID: licenseService.machineID
        )
    }

    private func refreshPermissionMenuItems() {
        menuComponents.accessibilityStateItem.title = StatusPresentation.accessibilityMenuTitle(
            isTrusted: AXIsProcessTrusted()
        )
        menuComponents.microphoneStateItem.title = StatusPresentation.microphoneMenuTitle(
            state: diagnostics.currentMicrophonePermissionState()
        )
    }

    private func refreshTextImprovementMenuItems() {
        let isEnabled = TextImprovementSettings.isEnabled()
        let hasModel = textImprovementRunner.availableModelPath() != nil
        let hasRuntime = textImprovementRunner.availableLlamaCliPath() != nil

        menuComponents.textImprovementStateItem.title = StatusPresentation.textImprovementMenuTitle(
            isEnabled: isEnabled,
            hasModel: hasModel,
            hasRuntime: hasRuntime
        )
        menuComponents.improveTextItem.title = "✨ Улучшить текст"
        menuComponents.improveTextItem.state = isEnabled ? .on : .off
        menuComponents.textImprovementToggleItem.state = isEnabled ? .on : .off
        menuComponents.textImprovementDownloadItem.title = hasModel
            ? "Переустановить модель улучшения текста"
            : "Скачать модель улучшения текста"
        menuComponents.improveTextItem.isEnabled = !isProcessing
    }

    private func refreshDiagnosticsMenuItem() {
        let summary = StatusPresentation.diagnosticsSummary(
            environmentIssue: diagnostics.currentIssue(),
            runtimeDiagnostic: activeRuntimeDiagnostic,
            licenseState: licenseService.state
        )
        menuComponents.diagnosticsItem.title = summary
        statusItem.button?.toolTip = summary
    }

    private func refreshIdlePresentation() {
        guard !recordingService.isRecording && !isProcessing else { return }

        let idleStatus = StatusPresentation.idleStatus(
            environmentIssue: diagnostics.currentIssue(),
            runtimeDiagnostic: activeRuntimeDiagnostic,
            licenseState: licenseService.state
        )
        setStatus(idleStatus.text, icon: idleStatus.icon)
    }

    private func setStatus(_ text: String, icon: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.title = icon
            self.menuComponents.statusItem.title = "Status: \(text)"
        }
    }

    private func setupHotkeys() {
        hotkeyMonitor = HotkeyMonitor(
            isRecording: { [weak self] in self?.recordingService.isRecording ?? false },
            isProcessing: { [weak self] in self?.isProcessing ?? false },
            onStartRequest: { [weak self] in self?.handleStartHotkey() },
            onStopRequest: { [weak self] in self?.stopRecordingAndProcess() }
        )
        hotkeyMonitor?.start()
    }

    private func handleStartHotkey() {
        if let reason = blockedRecordingReason() {
            handleBlockedRecording(reason)
            return
        }

        startRecording()
    }

    private func blockedRecordingReason() -> BlockedRecordingReason? {
        licenseService.normalizeStateIfNeeded()

        if let environmentIssue = diagnostics.currentIssue() {
            return .environment(environmentIssue)
        }

        switch licenseService.state {
        case .checking:
            return .checking
        case .expired:
            return .expired
        case .serverUnavailable:
            return .serverUnavailable
        case .active, .grace:
            return nil
        }
    }

    private func handleBlockedRecording(_ reason: BlockedRecordingReason) {
        switch reason {
        case .checking:
            maybePresentBlockedAlert(
                key: "license.checking",
                title: "Проверка лицензии",
                message: "MacDictate ещё завершает стартовую проверку лицензии. Попробуйте снова через пару секунд."
            )
            setStatus("Checking license...", icon: "⏳")

        case .expired:
            maybePresentBlockedAlert(
                key: "license.expired",
                title: "Лицензия истекла",
                message: "Пробный период или подписка завершены. Чтобы продолжить использование (Ваш ID: \(licenseService.machineID)), откройте страницу оплаты.",
                primaryButton: "Оплатить подписку",
                secondaryButton: "Позже",
                primaryAction: { [weak self] in
                    self?.openLicensePage()
                }
            )
            setStatus("License Expired", icon: "🛑")

        case .serverUnavailable:
            maybePresentBlockedAlert(
                key: "license.serverUnavailable",
                title: "Сервер лицензий недоступен",
                message: "MacDictate не смог подтвердить лицензию и локальный grace уже недоступен. Проверьте интернет и попробуйте позже."
            )
            setStatus("License Server Unavailable", icon: "⚠️")

        case .environment(let issue):
            let primaryButton: String?
            let primaryAction: (() -> Void)?

            switch issue {
            case .accessibilityMissing:
                primaryButton = "Открыть настройки"
                primaryAction = { [weak self] in self?.openAccessibilitySettings() }
            case .microphoneDenied:
                primaryButton = "Открыть микрофон"
                primaryAction = { [weak self] in self?.openMicrophoneSettings() }
            case .microphonePending, .modelMissing, .whisperMissing:
                primaryButton = nil
                primaryAction = nil
            }

            maybePresentBlockedAlert(
                key: "env.\(issue.statusText)",
                title: issue.alertTitle,
                message: issue.alertText,
                primaryButton: primaryButton,
                secondaryButton: "ОК",
                primaryAction: primaryAction
            )
            setStatus(issue.statusText, icon: "⚠️")
        }
    }

    private func maybePresentBlockedAlert(
        key: String,
        title: String,
        message: String,
        primaryButton: String? = nil,
        secondaryButton: String = "ОК",
        primaryAction: (() -> Void)? = nil
    ) {
        let now = Date()
        if lastBlockedAlertKey == key, now.timeIntervalSince(lastBlockedAlertAt) < blockedAlertThrottle {
            return
        }

        lastBlockedAlertKey = key
        lastBlockedAlertAt = now

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning

            if let primaryButton {
                alert.addButton(withTitle: primaryButton)
            }
            alert.addButton(withTitle: secondaryButton)

            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if primaryButton != nil && response == .alertFirstButtonReturn {
                primaryAction?()
            }
        }
    }

    private func startRecording() {
        switch recordingService.start() {
        case .success:
            recordDiagnostic(nil)
            setStatus("Listening...", icon: "🔴")
            NSSound(named: "Blow")?.play()

        case .failure(let error):
            recordDiagnostic(error.localizedDescription, severity: .error)
        }
    }

    private func stopRecordingAndProcess() {
        guard recordingService.isRecording else { return }

        recordingService.stop()
        isProcessing = true

        setStatus("Transcribing...", icon: "⏳")
        NSSound(named: "Pop")?.play()

        let audioPath = recordingService.recordingPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let transcription = self.whisperRunner.transcribe(audioPath: audioPath)
            let textResult: Result<(text: String, warning: String?), TranscriptionFailure>

            switch transcription {
            case .success(let text):
                let cleaned = self.whisperRunner.cleanOutput(text)
                if cleaned.isEmpty {
                    textResult = .success((text: "", warning: nil))
                } else {
                    textResult = .success(self.improveTextForAutomaticPipeline(cleaned))
                }
            case .failure(let error):
                textResult = .failure(error)
            }

            DispatchQueue.main.async {
                self.isProcessing = false

                switch textResult {
                case .success(let result):
                    if result.text.isEmpty {
                        self.recordDiagnostic(nil)
                    } else {
                        switch self.pasteService.paste(result.text) {
                        case .success:
                            if let warning = result.warning {
                                self.recordDiagnostic(warning, severity: .warning)
                            } else {
                                self.recordDiagnostic(nil)
                            }
                        case .failure(let error):
                            self.recordDiagnostic(error.localizedDescription, severity: .error)
                        }
                    }

                case .failure(let error):
                    self.recordDiagnostic(error.localizedDescription, severity: .error)
                }

                self.refreshIdlePresentation()
            }
        }
    }

    private func improveTextForAutomaticPipeline(_ text: String) -> (text: String, warning: String?) {
        guard TextImprovementSettings.isEnabled() else {
            return (text, nil)
        }

        DispatchQueue.main.async {
            self.setStatus("Improving text...", icon: "✨")
        }

        switch textImprovementRunner.improve(text) {
        case .success(let improved):
            return (improved, nil)
        case .failure(let error):
            return (text, error.localizedDescription)
        }
    }

    private func recordDiagnostic(_ message: String?, severity: DiagnosticSeverity = .warning) {
        if let message, !message.isEmpty {
            runtimeDiagnostic = RuntimeDiagnostic(severity: severity, message: message)
        } else {
            runtimeDiagnostic = nil
        }
        refreshPresentation()
    }

    private func checkPermissions() {
        let microphoneState = diagnostics.currentMicrophonePermissionState()
        if microphoneState == .notDetermined {
            diagnostics.requestMicrophoneAccess { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.recordDiagnostic(nil)
                    } else {
                        self?.recordDiagnostic("Доступ к микрофону отклонён.", severity: .warning)
                    }
                    self?.refreshPermissionMenuItems()
                    self?.refreshIdlePresentation()
                }
            }
        } else if microphoneState == .denied {
            recordDiagnostic("Доступ к микрофону не выдан.", severity: .warning)
        }

        if !AXIsProcessTrusted() {
            promptAccessibility()
        }

        refreshPermissionMenuItems()
        refreshIdlePresentation()
    }

    @objc func openLicensePage() {
        if let url = licenseService.purchaseURL() {
            NSWorkspace.shared.open(url)
        }
    }

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

    @objc func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "Удалить MacDictate?"
        alert.informativeText = "Вы уверены? Это действие безвозвратно удалит саму программу и сотрет нейросеть Whisper (~1.6 ГБ) с вашего диска."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Удалить полностью")
        alert.addButton(withTitle: "Отмена")

        if alert.runModal() == .alertFirstButtonReturn {
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

    private func executeSelfDestruct() {
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate"
        try? FileManager.default.removeItem(atPath: modelsDir)

        let appPath = Bundle.main.bundlePath
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

        NSApplication.shared.terminate(nil)
    }

    @objc func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        let alert = NSAlert()
        alert.messageText = "Настройки Отслеживания (Универсальный доступ)"
        alert.informativeText = "Поставьте галочку напротив MacDictate.\n\n❗️ СИСТЕМНЫЙ БАГ MACOS: Если программа не реагирует на галочку (например, после обновления версий) — вам НУЖНО физически выделить MacDictate мышкой, нажать минус (-) в самом низу списка, а затем нажать плюс (+) и добавить программу заново из папки Программы."
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)

        if !AXIsProcessTrusted() {
            startPermissionPolling()
        }

        alert.runModal()
    }

    @objc func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    private func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Требуется Универсальный доступ"
        alert.informativeText = "MacDictate нужно разрешение для отслеживания двойного нажатия системной клавиши Option (Alt).\n\nНажмите «Открыть Настройки» и поставьте галочку. \n\n❗️ ЕСЛИ ОБНОВЛЯЕТЕ ВЕРСИЮ: Старая галочка может \"залипать\". Выделите её мышкой, нажмите минус (-) внизу списка, а затем добавьте новую программу плюсом (+)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть Настройки")
        alert.addButton(withTitle: "Позже")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            startPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.refreshPermissionMenuItems()
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.recordDiagnostic(nil)
                self.promptRestart()
            }
        }
    }

    private func promptRestart() {
        let alert = NSAlert()
        alert.messageText = "Разрешение получено! 🎉"
        alert.informativeText = "Спасибо! Чтобы горячие клавиши заработали, программе нужно перезагрузиться."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Перезагрузить")

        if alert.runModal() == .alertFirstButtonReturn {
            relaunchApp()
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

                let script = "tell application \"System Events\" to delete login item \"MacDictate\""
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = ["-e", script]
                try? task.run()
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on

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

    private func handleVersionUpgrade() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let versionKey = "\(currentVersion)_\(currentBuild)"
        UserDefaults.standard.set(versionKey, forKey: "LastLaunchedVersion")
    }

    @objc func manualCheckForUpdates() {
        performUpdateCheck(isManual: true)
    }

    func performUpdateCheck(isManual: Bool) {
        let updateUrlString = "https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest"

        guard let url = URL(string: updateUrlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
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
                   let releasePageURL = json["html_url"] as? String,
                   let releaseNotes = json["body"] as? String {

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
                            if alert.runModal() == .alertFirstButtonReturn,
                               let downloadURL = URL(string: releasePageURL) {
                                NSWorkspace.shared.open(downloadURL)
                            }
                        }
                    } else if isManual {
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
        }.resume()
    }
}
