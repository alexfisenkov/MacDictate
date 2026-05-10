import Cocoa

extension AppController {
    func handleStartHotkey() {
        if let reason = blockedRecordingReason() {
            handleBlockedRecording(reason)
            return
        }

        startRecording()
    }

    func stopRecordingAndProcess() {
        guard recordingService.isRecording else { return }

        recordingService.stop()
        isProcessing = true

        setStatus("Transcribing...", icon: "⏳")
        NSSound(named: "Pop")?.play()

        let audioPath = recordingService.recordingPath
        let debugSession = activeDebugSession
        activeDebugSession = nil
        debugSession?.record("recording_stopped")
        debugSession?.copyAudio(from: audioPath)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            debugSession?.record("whisper_started")
            let transcription = self.whisperRunner.transcribe(audioPath: audioPath)
            let textResult: Result<(text: String, warning: String?), TranscriptionFailure>

            switch transcription {
            case .success(let text):
                debugSession?.record("whisper_finished", details: ["rawCharacters": String(text.count)])
                debugSession?.writeTextFile("01_whisper_raw.txt", text)
                let cleaned = self.whisperRunner.cleanOutput(text)
                debugSession?.writeTextFile("02_whisper_cleaned.txt", cleaned)
                if cleaned.isEmpty {
                    debugSession?.record("whisper_cleaned_empty")
                    textResult = .success((text: "", warning: nil))
                } else {
                    textResult = .success(self.improveTextForAutomaticPipeline(cleaned, debugSession: debugSession))
                }
            case .failure(let error):
                debugSession?.record("whisper_failed", details: ["error": error.localizedDescription])
                debugSession?.writeTextFile("errors.txt", "Whisper: \(error.localizedDescription)\n")
                debugSession?.finish(finalText: "", warning: error.localizedDescription)
                textResult = .failure(error)
            }

            DispatchQueue.main.async {
                self.isProcessing = false

                switch textResult {
                case .success(let result):
                    if result.text.isEmpty {
                        debugSession?.finish(finalText: "", warning: result.warning)
                        self.recordDiagnostic(nil)
                    } else {
                        self.lastDictationStore.save(result.text)
                        self.refreshLastDictationMenuItem()
                        debugSession?.record("last_dictation_saved", details: ["characters": String(result.text.count)])

                        switch self.pasteService.paste(result.text) {
                        case .success:
                            debugSession?.record("paste_succeeded")
                            debugSession?.finish(finalText: result.text, warning: result.warning)
                            if let warning = result.warning {
                                self.recordDiagnostic(warning, severity: .warning)
                            } else {
                                self.recordDiagnostic(nil)
                            }
                        case .failure(let error):
                            debugSession?.record("paste_failed", details: ["error": error.localizedDescription])
                            debugSession?.finish(finalText: result.text, warning: error.localizedDescription)
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

    func recordDiagnostic(_ message: String?, severity: DiagnosticSeverity = .warning) {
        if let message, !message.isEmpty {
            runtimeDiagnostic = RuntimeDiagnostic(severity: severity, message: message)
        } else {
            runtimeDiagnostic = nil
        }
        refreshPresentation()
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
            case .microphonePending:
                primaryButton = "Разрешить микрофон"
                primaryAction = { [weak self] in self?.requestMicrophonePermission() }
            case .microphoneDenied:
                primaryButton = "Открыть микрофон"
                primaryAction = { [weak self] in self?.openMicrophoneSettings() }
            case .modelMissing, .whisperMissing:
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
            activeDebugSession = debugSessionLogger.startSession(context: DebugSessionContext(
                appVersion: appVersionString(),
                textImprovementEnabled: TextImprovementSettings.isEnabled(),
                machineID: licenseService.machineID
            ))
            activeDebugSession?.record("recording_started")
            recordDiagnostic(nil)
            setStatus("Listening...", icon: "🔴")
            NSSound(named: "Blow")?.play()

        case .failure(let error):
            recordDiagnostic(error.localizedDescription, severity: .error)
        }
    }

    private func improveTextForAutomaticPipeline(_ text: String, debugSession: DebugSession?) -> (text: String, warning: String?) {
        guard TextImprovementSettings.isEnabled() else {
            debugSession?.record("qwen_skipped", details: ["reason": "text improvement disabled"])
            return (text, nil)
        }

        DispatchQueue.main.async {
            self.setStatus("Improving text...", icon: "✨")
        }

        debugSession?.writeTextFile("03_qwen_input.txt", text)
        debugSession?.record("qwen_started", details: ["inputCharacters": String(text.count)])

        switch textImprovementRunner.improveWithTrace(text) {
        case .success(let output):
            var qwenFinishedDetails = [
                "inputCharacters": String(output.trace.input.count),
                "rawCharacters": String(output.trace.rawOutput.count),
                "cleanedCharacters": String(output.trace.cleanedOutput.count),
                "finalCharacters": String(output.trace.finalOutput.count),
                "modelPath": output.trace.modelPath,
                "runtimePath": output.trace.runtimePath
            ]
            if let reason = output.trace.validationFallbackReason {
                qwenFinishedDetails["validationFallbackReason"] = reason
            }
            if let reason = output.trace.retryTriggerReason {
                qwenFinishedDetails["retryTriggerReason"] = reason
            }
            debugSession?.record("qwen_finished", details: qwenFinishedDetails)
            debugSession?.writeTextFile("04_qwen_prompt.txt", output.trace.prompt)
            debugSession?.writeTextFile("04b_qwen_preformatted_input.txt", output.trace.preparedInput)
            if let initialRawOutput = output.trace.initialRawOutput {
                debugSession?.writeTextFile("05a_qwen_initial_raw_output.txt", initialRawOutput)
            }
            if let initialCleanedOutput = output.trace.initialCleanedOutput {
                debugSession?.writeTextFile("06a_qwen_initial_cleaned_output.txt", initialCleanedOutput)
            }
            debugSession?.writeTextFile("05_qwen_raw_output.txt", output.trace.rawOutput)
            debugSession?.writeTextFile("06_qwen_cleaned_output.txt", output.trace.cleanedOutput)
            debugSession?.writeTextFile("06b_qwen_final_after_formatter.txt", output.trace.finalOutput)
            if let reason = output.trace.validationFallbackReason {
                debugSession?.writeTextFile("06c_qwen_validation.txt", "fallbackReason: \(reason)\n")
            }
            if let reason = output.trace.retryTriggerReason {
                debugSession?.writeTextFile("06d_qwen_retry.txt", "retryTriggerReason: \(reason)\n")
            }
            debugSession?.writeTextFile("qwen_arguments.txt", output.trace.arguments.joined(separator: "\n"))
            return (output.text, nil)
        case .failure(let error):
            debugSession?.record("qwen_failed", details: ["error": error.localizedDescription])
            debugSession?.writeTextFile("errors.txt", "Qwen: \(error.localizedDescription)\n")
            return (text, error.localizedDescription)
        }
    }

    private func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(shortVersion) (\(build))"
    }
}
