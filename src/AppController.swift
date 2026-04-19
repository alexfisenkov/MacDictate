import Cocoa
import AVFoundation
import ServiceManagement

class AppController {

    enum LicenseState {
        case checking
        case active(LicenseSnapshot)
        case grace(LicenseSnapshot, Date)
        case expired(LicenseSnapshot?)
        case serverUnavailable(LicenseSnapshot?)
    }

    enum MicrophonePermissionState {
        case authorized
        case notDetermined
        case denied
    }

    enum DiagnosticSeverity {
        case ok
        case warning
        case error

        var prefix: String {
            switch self {
            case .ok:
                return "✅"
            case .warning:
                return "⚠️"
            case .error:
                return "🛑"
            }
        }
    }

    struct RuntimeDiagnostic {
        let severity: DiagnosticSeverity
        let message: String
    }

    struct LicenseSnapshot: Codable {
        let machineID: String
        let isPaid: Bool
        let isActive: Bool
        let daysLeft: Int
        let expiresAt: Date?
        let checkedAt: Date
    }

    struct LicenseStatusResponse: Decodable {
        let deviceId: String
        let isPaid: Bool
        let isActive: Bool
        let expiresAt: String?
        let daysLeft: Int
    }

    enum EnvironmentIssue {
        case accessibilityMissing
        case microphonePending
        case microphoneDenied
        case modelMissing
        case whisperMissing

        var statusText: String {
            switch self {
            case .accessibilityMissing:
                return "Needs Accessibility"
            case .microphonePending:
                return "Waiting for Microphone"
            case .microphoneDenied:
                return "Microphone Access Needed"
            case .modelMissing:
                return "Model Not Found"
            case .whisperMissing:
                return "whisper-cli Not Found"
            }
        }

        var diagnosticText: String {
            switch self {
            case .accessibilityMissing:
                return "Нужен универсальный доступ для отслеживания клавиши Option."
            case .microphonePending:
                return "Ожидается решение по доступу к микрофону."
            case .microphoneDenied:
                return "Доступ к микрофону не выдан."
            case .modelMissing:
                return "Модель Whisper не найдена."
            case .whisperMissing:
                return "Не найден whisper-cli."
            }
        }

        var alertTitle: String {
            switch self {
            case .accessibilityMissing:
                return "Нужен Универсальный доступ"
            case .microphonePending, .microphoneDenied:
                return "Нужен доступ к микрофону"
            case .modelMissing:
                return "Модель Whisper не найдена"
            case .whisperMissing:
                return "Не найден whisper-cli"
            }
        }

        var alertText: String {
            switch self {
            case .accessibilityMissing:
                return "MacDictate не сможет отслеживать двойное нажатие Option без разрешения в настройках macOS."
            case .microphonePending:
                return "MacDictate ждёт ответ macOS по доступу к микрофону. Подтвердите доступ и попробуйте ещё раз."
            case .microphoneDenied:
                return "MacDictate не сможет записывать речь, пока доступ к микрофону не разрешён в настройках macOS."
            case .modelMissing:
                return "Локальная модель Whisper не найдена. Перезапустите приложение, чтобы открыть загрузчик модели."
            case .whisperMissing:
                return "MacDictate не нашёл whisper-cli ни внутри приложения, ни в системных путях Homebrew."
            }
        }
    }

    enum BlockedRecordingReason {
        case checking
        case expired
        case serverUnavailable
        case environment(EnvironmentIssue)
    }

    enum TranscriptionFailure: LocalizedError {
        case modelMissing
        case whisperMissing
        case launchFailed(String)
        case nonZeroExit(Int32, String)
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .modelMissing:
                return "Модель Whisper не найдена."
            case .whisperMissing:
                return "Не найден whisper-cli."
            case .launchFailed(let detail):
                return "Не удалось запустить whisper-cli: \(detail)"
            case .nonZeroExit(let code, let detail):
                if detail.isEmpty {
                    return "whisper-cli завершился с ошибкой (код \(code))."
                }
                return "whisper-cli завершился с ошибкой (код \(code)): \(detail)"
            case .outputMissing:
                return "Whisper не вернул результат распознавания."
            }
        }
    }

    var statusItem: NSStatusItem!
    var audioRecorder: AVAudioRecorder?
    var isRecording = false
    var isProcessing = false
    var lastOptionPressTime: TimeInterval = 0
    let tempWavPath = "/tmp/mac_dictate_dist.wav"

    var machineID: String = ""
    var licenseState: LicenseState = .checking
    var licenseMenuItem: NSMenuItem!
    var diagnosticsMenuItem: NSMenuItem!
    var accessibilityStateItem: NSMenuItem!
    var microphoneStateItem: NSMenuItem!

    var permissionTimer: Timer?
    var licenseRefreshTimer: Timer?
    var wakeObserver: NSObjectProtocol?
    var isLicenseCheckInFlight = false
    var lastRuntimeDiagnostic: RuntimeDiagnostic?
    var lastBlockedAlertKey: String?
    var lastBlockedAlertAt: Date = .distantPast

    let licenseCacheKey = "MacDictateLicenseSnapshot"
    let machineIDKey = "MacDictateUID"
    let licenseRefreshInterval: TimeInterval = 30 * 60
    let offlineGraceInterval: TimeInterval = 72 * 60 * 60
    let expiryGraceInterval: TimeInterval = 24 * 60 * 60
    let blockedAlertThrottle: TimeInterval = 15

    deinit {
        permissionTimer?.invalidate()
        licenseRefreshTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    // Поиск динамической модели
    func getLatestModelPath() -> String? {
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.macdictate/models"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: modelsDir) else { return nil }

        let binFiles = files.filter { $0.hasSuffix(".bin") }
        if binFiles.isEmpty { return nil }

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
    func getWhisperCliPath() -> String? {
        var candidates: [String] = []
        if let resourcePath = Bundle.main.resourcePath {
            candidates.append(resourcePath + "/bin/whisper-cli")
        }
        candidates.append("/opt/homebrew/bin/whisper-cli")
        candidates.append("/usr/local/bin/whisper-cli")

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }

    func start() {
        handleVersionUpgrade()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🎙️"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        machineID = getMachineID()

        licenseMenuItem = NSMenuItem(title: "⏳ Лицензия: проверка...", action: #selector(openLicensePage), keyEquivalent: "")
        licenseMenuItem.target = self
        menu.addItem(licenseMenuItem)

        diagnosticsMenuItem = NSMenuItem(title: "Диагностика: Инициализация...", action: nil, keyEquivalent: "")
        menu.addItem(diagnosticsMenuItem)
        menu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: "📖 Инструкция", action: #selector(showInstructions), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        menu.addItem(NSMenuItem.separator())

        let settingsMenuItem = NSMenuItem(title: "⚙️ Настройки", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()

        accessibilityStateItem = NSMenuItem(title: "♿️ Универсальный доступ: проверка...", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(accessibilityStateItem)

        microphoneStateItem = NSMenuItem(title: "🎤 Микрофон: проверка...", action: nil, keyEquivalent: "")
        settingsSubmenu.addItem(microphoneStateItem)
        settingsSubmenu.addItem(NSMenuItem.separator())

        let accessibilityAction = NSMenuItem(title: "Открыть настройки отслеживания", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityAction.target = self
        settingsSubmenu.addItem(accessibilityAction)

        let microphoneAction = NSMenuItem(title: "Открыть настройки микрофона", action: #selector(openMicrophoneSettings), keyEquivalent: "")
        microphoneAction.target = self
        settingsSubmenu.addItem(microphoneAction)
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

        menu.addItem(NSMenuItem.separator())
        let updateItem = NSMenuItem(title: "🔄 Проверить обновления", action: #selector(manualCheckForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu

        restoreCachedLicenseState()
        refreshPermissionMenuItems()
        refreshPresentation()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.normalizeLicenseStateIfNeeded()
            self.checkLicenseStatus(promoteCheckingState: !self.allowsDictationForCurrentLicenseState)
        }

        checkPermissions()
        setupHotkeys()
        startLicenseRefreshLoop()

        performUpdateCheck(isManual: false)
        checkLicenseStatus(promoteCheckingState: !allowsDictationForCurrentLicenseState)
    }

    func getMachineID() -> String {
        if let saved = UserDefaults.standard.string(forKey: machineIDKey) {
            return saved
        }

        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var uniqueId = "MD-UNKNOWN"
        if let uuidRange = output.range(of: "\"IOPlatformUUID\" = \"") {
            let substring = output[uuidRange.upperBound...]
            if let endQuote = substring.range(of: "\"") {
                let hardwareUUID = String(substring[..<endQuote.lowerBound])
                uniqueId = "MD-" + hardwareUUID.prefix(8)
            }
        }

        if uniqueId == "MD-UNKNOWN" {
            uniqueId = "MD-\(UUID().uuidString.prefix(8))"
        }

        UserDefaults.standard.set(uniqueId, forKey: machineIDKey)
        return uniqueId
    }

    func restoreCachedLicenseState() {
        guard let snapshot = loadCachedLicenseSnapshot(),
              let deadline = graceDeadline(for: snapshot),
              deadline > Date() else {
            licenseState = .checking
            return
        }

        licenseState = .grace(snapshot, deadline)
    }

    func loadCachedLicenseSnapshot() -> LicenseSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: licenseCacheKey),
              let snapshot = try? JSONDecoder().decode(LicenseSnapshot.self, from: data),
              snapshot.machineID == machineID else {
            return nil
        }

        return snapshot
    }

    func persistLicenseSnapshot(_ snapshot: LicenseSnapshot?) {
        guard let snapshot = snapshot else {
            UserDefaults.standard.removeObject(forKey: licenseCacheKey)
            return
        }

        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: licenseCacheKey)
        }
    }

    func graceDeadline(for snapshot: LicenseSnapshot) -> Date? {
        guard snapshot.isActive else { return nil }

        let boundedByCheck = snapshot.checkedAt.addingTimeInterval(offlineGraceInterval)
        guard let expiresAt = snapshot.expiresAt else { return boundedByCheck }
        return min(boundedByCheck, expiresAt.addingTimeInterval(expiryGraceInterval))
    }

    func licenseStatusURL() -> URL? {
        var components = URLComponents(string: "https://macdictate.pro/api/license/status")
        components?.queryItems = [URLQueryItem(name: "deviceId", value: machineID)]
        return components?.url
    }

    func licenseSnapshot(from response: LicenseStatusResponse) -> LicenseSnapshot {
        LicenseSnapshot(
            machineID: machineID,
            isPaid: response.isPaid,
            isActive: response.isActive,
            daysLeft: response.daysLeft,
            expiresAt: parseISO8601Date(response.expiresAt),
            checkedAt: Date()
        )
    }

    func parseISO8601Date(_ value: String?) -> Date? {
        guard let value else { return nil }

        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatterWithFractional.date(from: value) {
            return parsed
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    func checkLicenseStatus(promoteCheckingState: Bool = false) {
        guard !isLicenseCheckInFlight, let url = licenseStatusURL() else { return }

        isLicenseCheckInFlight = true
        if promoteCheckingState {
            licenseState = .checking
            refreshPresentation()
        } else {
            refreshDiagnosticsMenuItem()
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLicenseCheckInFlight = false

                guard error == nil,
                      let data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let decoded = try? JSONDecoder().decode(LicenseStatusResponse.self, from: data) else {
                    self.handleLicenseCheckFailure(error: error)
                    return
                }

                self.handleLicenseCheckSuccess(response: decoded)
            }
        }

        task.resume()
    }

    func handleLicenseCheckSuccess(response: LicenseStatusResponse) {
        let snapshot = licenseSnapshot(from: response)
        lastRuntimeDiagnostic = nil

        if snapshot.isActive {
            persistLicenseSnapshot(snapshot)
            licenseState = .active(snapshot)
        } else {
            persistLicenseSnapshot(nil)
            licenseState = .expired(snapshot)
        }

        refreshPresentation()
    }

    func handleLicenseCheckFailure(error: Error?) {
        let cachedSnapshot = loadCachedLicenseSnapshot()

        if let snapshot = cachedSnapshot,
           let deadline = graceDeadline(for: snapshot),
           deadline > Date() {
            licenseState = .grace(snapshot, deadline)
        } else if case .expired(let previousExpired) = licenseState {
            licenseState = .expired(previousExpired)
        } else {
            licenseState = .serverUnavailable(cachedSnapshot)
        }

        let baseMessage = "Сервер лицензий временно недоступен."
        if let error {
            lastRuntimeDiagnostic = RuntimeDiagnostic(
                severity: .warning,
                message: "\(baseMessage) \(error.localizedDescription)"
            )
        } else {
            lastRuntimeDiagnostic = RuntimeDiagnostic(
                severity: .warning,
                message: baseMessage
            )
        }

        refreshPresentation()
    }

    func startLicenseRefreshLoop() {
        licenseRefreshTimer?.invalidate()
        licenseRefreshTimer = Timer.scheduledTimer(withTimeInterval: licenseRefreshInterval, repeats: true) { [weak self] _ in
            self?.checkLicenseStatus()
        }
        licenseRefreshTimer?.tolerance = 60
    }

    var currentLicenseSnapshot: LicenseSnapshot? {
        switch licenseState {
        case .checking:
            return nil
        case .active(let snapshot):
            return snapshot
        case .grace(let snapshot, _):
            return snapshot
        case .expired(let snapshot):
            return snapshot
        case .serverUnavailable(let snapshot):
            return snapshot
        }
    }

    var allowsDictationForCurrentLicenseState: Bool {
        switch licenseState {
        case .active, .grace:
            return true
        case .checking, .expired, .serverUnavailable:
            return false
        }
    }

    func refreshPresentation() {
        normalizeLicenseStateIfNeeded()
        refreshLicenseMenuItem()
        refreshPermissionMenuItems()
        refreshDiagnosticsMenuItem()
        refreshIdlePresentation()
    }

    func normalizeLicenseStateIfNeeded() {
        switch licenseState {
        case .grace(let snapshot, let deadline) where deadline <= Date():
            licenseState = .serverUnavailable(snapshot)
        default:
            break
        }
    }

    func refreshLicenseMenuItem() {
        let title: String

        switch licenseState {
        case .checking:
            title = "⏳ Лицензия: проверка... [\(machineID)]"
        case .active(let snapshot):
            if snapshot.isPaid {
                title = "💎 Лицензия: активна [\(machineID)]"
            } else {
                title = "🎁 Триал: \(snapshot.daysLeft) дн. [\(machineID)]"
            }
        case .grace(let snapshot, let deadline):
            let until = shortDateTime(deadline)
            if snapshot.isPaid {
                title = "🟡 Grace: лицензия до \(until) [\(machineID)]"
            } else {
                title = "🟡 Grace: триал до \(until) [\(machineID)]"
            }
        case .expired:
            title = "🛑 Лицензия: истекла [\(machineID)]"
        case .serverUnavailable:
            title = "⚠️ Лицензия: сервер недоступен [\(machineID)]"
        }

        licenseMenuItem.title = title
    }

    func refreshPermissionMenuItems() {
        accessibilityStateItem.title = AXIsProcessTrusted()
            ? "♿️ Универсальный доступ: выдан"
            : "♿️ Универсальный доступ: не выдан"

        switch currentMicrophonePermissionState() {
        case .authorized:
            microphoneStateItem.title = "🎤 Микрофон: доступ разрешён"
        case .notDetermined:
            microphoneStateItem.title = "🎤 Микрофон: ожидает подтверждения"
        case .denied:
            microphoneStateItem.title = "🎤 Микрофон: доступ не выдан"
        }
    }

    func refreshDiagnosticsMenuItem() {
        let summary: String

        if let environmentIssue = currentEnvironmentIssue() {
            summary = "Диагностика: \(environmentIssue.diagnosticText)"
        } else if let diagnostic = lastRuntimeDiagnostic {
            summary = "Диагностика: \(diagnostic.severity.prefix) \(diagnostic.message)"
        } else {
            switch licenseState {
            case .grace(_, let deadline):
                summary = "Диагностика: offline grace активен до \(shortDateTime(deadline))."
            case .checking:
                summary = "Диагностика: выполняется проверка лицензии."
            case .serverUnavailable:
                summary = "Диагностика: сервер лицензий недоступен."
            case .expired:
                summary = "Диагностика: лицензия истекла."
            case .active:
                summary = "Диагностика: OK"
            }
        }

        diagnosticsMenuItem.title = summary
        statusItem.button?.toolTip = summary
    }

    func refreshIdlePresentation() {
        guard !isRecording && !isProcessing else { return }

        if let environmentIssue = currentEnvironmentIssue() {
            setStatus(environmentIssue.statusText, icon: "⚠️")
            return
        }

        if let diagnostic = lastRuntimeDiagnostic {
            let icon = diagnostic.severity == .warning ? "⚠️" : diagnostic.severity == .error ? "🛑" : "🎙️"
            setStatus(diagnostic.message, icon: icon)
            return
        }

        switch licenseState {
        case .checking:
            setStatus("Checking license...", icon: "⏳")
        case .active:
            setStatus("Ready", icon: "🎙️")
        case .grace:
            setStatus("Offline Grace", icon: "🟡")
        case .expired:
            setStatus("License Expired", icon: "🛑")
        case .serverUnavailable:
            setStatus("License Server Unavailable", icon: "⚠️")
        }
    }

    func currentEnvironmentIssue() -> EnvironmentIssue? {
        if !AXIsProcessTrusted() {
            return .accessibilityMissing
        }

        switch currentMicrophonePermissionState() {
        case .authorized:
            break
        case .notDetermined:
            return .microphonePending
        case .denied:
            return .microphoneDenied
        }

        if getLatestModelPath() == nil {
            return .modelMissing
        }

        if getWhisperCliPath() == nil {
            return .whisperMissing
        }

        return nil
    }

    func currentMicrophonePermissionState() -> MicrophonePermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func recordDiagnostic(_ message: String?, severity: DiagnosticSeverity = .warning) {
        if let message, !message.isEmpty {
            lastRuntimeDiagnostic = RuntimeDiagnostic(severity: severity, message: message)
        } else {
            lastRuntimeDiagnostic = nil
        }
        refreshPresentation()
    }

    func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @objc func openLicensePage() {
        if let url = URL(string: "https://macdictate.pro/?uid=\(machineID)#pricing") {
            NSWorkspace.shared.open(url)
        }
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

    func checkPermissions() {
        let microphoneState = currentMicrophonePermissionState()
        if microphoneState == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
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

    func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Требуется Универсальный доступ"
        alert.informativeText = "MacDictate нужно разрешение для отслеживания двойного нажатия системной клавиши Option (Alt).\n\nНажмите «Открыть Настройки» и поставьте галочку. \n\n❗️ ЕСЛИ ОБНОВЛЯЕТЕ ВЕРСИЮ: Старая галочка может \"залипать\". Выделите её мышкой, нажмите минус (-) внизу списка, а затем добавьте новую программу плюсом (+)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть Настройки")
        alert.addButton(withTitle: "Позже")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            startPermissionPolling()
        }
    }

    func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.refreshPermissionMenuItems()
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.recordDiagnostic(nil)
                self.promptRestart()
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

    func handleVersionUpgrade() {
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

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                            if alert.runModal() == .alertFirstButtonReturn, let downloadUrl = URL(string: releasePageUrl) {
                                NSWorkspace.shared.open(downloadUrl)
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

            if event.keyCode != 58 {
                return
            }

            let isPressedDown = event.modifierFlags.contains(.option)
            guard isPressedDown else { return }

            let now = Date().timeIntervalSince1970

            if self.isRecording {
                self.stopRecordingAndProcess()
                self.lastOptionPressTime = now
                return
            }

            if self.isProcessing {
                self.lastOptionPressTime = now
                return
            }

            let isDoublePress = now - self.lastOptionPressTime < 0.4
            self.lastOptionPressTime = now

            guard isDoublePress else { return }

            if let reason = self.blockedRecordingReason() {
                self.handleBlockedRecording(reason)
                return
            }

            self.startRecording()
        }
    }

    func blockedRecordingReason() -> BlockedRecordingReason? {
        normalizeLicenseStateIfNeeded()

        if let environmentIssue = currentEnvironmentIssue() {
            return .environment(environmentIssue)
        }

        switch licenseState {
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

    func handleBlockedRecording(_ reason: BlockedRecordingReason) {
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
                message: "Пробный период или подписка завершены. Чтобы продолжить использование (Ваш ID: \(machineID)), откройте страницу оплаты.",
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

    func maybePresentBlockedAlert(
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

    func startRecording() {
        guard !isRecording else { return }

        let audioFilename = URL(fileURLWithPath: tempWavPath)
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
            audioRecorder?.prepareToRecord()
            if audioRecorder?.record() != true {
                throw NSError(domain: "MacDictate.Recording", code: 1, userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder не начал запись."])
            }

            isRecording = true
            recordDiagnostic(nil)
            setStatus("Listening...", icon: "🔴")
            NSSound(named: "Blow")?.play()
        } catch {
            audioRecorder = nil
            recordDiagnostic("Не удалось начать запись. Проверьте доступ к микрофону.", severity: .error)
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
                self.isProcessing = false

                switch output {
                case .success(let text):
                    let cleaned = self.cleanWhisperOutput(text)
                    if cleaned.isEmpty {
                        self.recordDiagnostic(nil)
                    } else {
                        let didPaste = self.pasteText(cleaned)
                        if didPaste {
                            self.recordDiagnostic(nil)
                        }
                    }

                case .failure(let error):
                    self.recordDiagnostic(error.localizedDescription, severity: .error)
                }

                self.refreshIdlePresentation()
            }
        }
    }

    func cleanupTemporaryFiles() {
        try? FileManager.default.removeItem(atPath: tempWavPath)
        try? FileManager.default.removeItem(atPath: tempWavPath + ".txt")
    }

    func runWhisper() -> Result<String, TranscriptionFailure> {
        guard let modelPath = getLatestModelPath() else {
            cleanupTemporaryFiles()
            return .failure(.modelMissing)
        }

        guard let whisperCli = getWhisperCliPath() else {
            cleanupTemporaryFiles()
            return .failure(.whisperMissing)
        }

        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.launchPath = whisperCli
        task.arguments = ["-m", modelPath, "-f", tempWavPath, "-l", "ru", "-nt", "-otxt"]
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
            task.waitUntilExit()

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard task.terminationStatus == 0 else {
                cleanupTemporaryFiles()
                return .failure(.nonZeroExit(task.terminationStatus, stderrText))
            }

            let txtPath = tempWavPath + ".txt"
            guard FileManager.default.fileExists(atPath: txtPath) else {
                cleanupTemporaryFiles()
                return .failure(.outputMissing)
            }

            let transcribedResult = try String(contentsOfFile: txtPath, encoding: .utf8)
            cleanupTemporaryFiles()
            return .success(transcribedResult)
        } catch {
            cleanupTemporaryFiles()
            return .failure(.launchFailed(error.localizedDescription))
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

    @discardableResult
    func pasteText(_ input: String) -> Bool {
        if input.isEmpty { return true }
        let text = input + " "

        let pasteboard = NSPasteboard.general
        let oldString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            recordDiagnostic("Не удалось записать текст во временный буфер обмена.", severity: .error)
            return false
        }

        guard simulatePaste() else {
            if let oldString {
                pasteboard.clearContents()
                pasteboard.setString(oldString, forType: .string)
            }
            recordDiagnostic("Не удалось вставить текст в активное окно.", severity: .error)
            return false
        }

        NSSound(named: "Tink")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let oldString {
                pasteboard.clearContents()
                pasteboard.setString(oldString, forType: .string)
            }
        }

        return true
    }

    func simulatePaste() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        usleep(20_000)
        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
