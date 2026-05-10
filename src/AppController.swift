import Cocoa

final class AppController: NSObject {
    let licenseService = LicenseService()
    let whisperRunner = WhisperRunner()
    let textImprovementRunner = TextImprovementRunner()
    lazy var diagnostics = EnvironmentDiagnostics(whisperRunner: whisperRunner)
    let recordingService = RecordingService()
    let pasteService = PasteService()
    let debugSessionLogger = DebugSessionLogger()
    let lastDictationStore = LastDictationStore()
    let updateChecker = UpdateChecker()

    var statusItem: NSStatusItem!
    var menuComponents: AppMenuComponents!
    var hotkeyMonitor: HotkeyMonitor?
    var permissionTimer: Timer?
    var wakeObserver: NSObjectProtocol?
    var textImprovementWindowController: NSWindowController?
    var activeTextImprovementDownloader: ModelDownloader?
    var activeDebugSession: DebugSession?

    var runtimeDiagnostic: RuntimeDiagnostic?
    var isProcessing = false
    var lastBlockedAlertKey: String?
    var lastBlockedAlertAt: Date = .distantPast

    let blockedAlertThrottle: TimeInterval = 15

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

    func refreshPresentation() {
        licenseService.normalizeStateIfNeeded()
        refreshLicenseMenuItem()
        refreshPermissionMenuItems()
        refreshTextImprovementMenuItems()
        refreshLastDictationMenuItem()
        refreshDiagnosticsMenuItem()
        refreshIdlePresentation()
    }

    func refreshPermissionMenuItems() {
        menuComponents.accessibilityStateItem.title = StatusPresentation.accessibilityMenuTitle(
            isTrusted: AXIsProcessTrusted()
        )
        menuComponents.microphoneStateItem.title = StatusPresentation.microphoneMenuTitle(
            state: diagnostics.currentMicrophonePermissionState()
        )
    }

    func refreshTextImprovementMenuItems() {
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

    func refreshLastDictationMenuItem() {
        if let entry = lastDictationStore.latest() {
            menuComponents.copyLastDictationItem.title = "Скопировать последнюю диктовку"
            menuComponents.copyLastDictationItem.toolTip = "Сохранено: \(StatusPresentation.shortDateTime(entry.createdAt)), \(entry.text.count) симв."
            menuComponents.copyLastDictationItem.isEnabled = true
        } else {
            menuComponents.copyLastDictationItem.title = "Скопировать последнюю диктовку"
            menuComponents.copyLastDictationItem.toolTip = "Последняя диктовка ещё не сохранена."
            menuComponents.copyLastDictationItem.isEnabled = false
        }
    }

    func refreshIdlePresentation() {
        guard !recordingService.isRecording && !isProcessing else { return }

        let idleStatus = StatusPresentation.idleStatus(
            environmentIssue: diagnostics.currentIssue(),
            runtimeDiagnostic: activeRuntimeDiagnostic,
            licenseState: licenseService.state
        )
        setStatus(idleStatus.text, icon: idleStatus.icon)
    }

    func setStatus(_ text: String, icon: String) {
        DispatchQueue.main.async {
            self.renderStatusBarIcon(icon)
            self.menuComponents.statusItem.title = "Status: \(text)"
        }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusBarButton()

        menuComponents = MenuBuilder.build(for: self)
        statusItem.menu = menuComponents.menu
    }

    private func configureStatusBarButton() {
        renderStatusBarIcon("")
    }

    private func renderStatusBarIcon(_ icon: String) {
        guard let button = statusItem.button else { return }

        if icon.isEmpty, let image = NSImage(named: "mic_menubar") {
            image.isTemplate = true
            image.size = NSSize(width: 17, height: 17)
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.image = nil
            button.imagePosition = .noImage
            button.title = icon.isEmpty ? "MacDictate" : icon
        }
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

    private func refreshLicenseMenuItem() {
        menuComponents.licenseItem.title = StatusPresentation.licenseMenuTitle(
            state: licenseService.state,
            machineID: licenseService.machineID
        )
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

    private func setupHotkeys() {
        hotkeyMonitor = HotkeyMonitor(
            isRecording: { [weak self] in self?.recordingService.isRecording ?? false },
            isProcessing: { [weak self] in self?.isProcessing ?? false },
            onStartRequest: { [weak self] in self?.handleStartHotkey() },
            onStopRequest: { [weak self] in self?.stopRecordingAndProcess() }
        )
        hotkeyMonitor?.start()
    }
}
