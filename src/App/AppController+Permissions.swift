import Cocoa

extension AppController {
    func checkPermissions() {
        let microphoneState = diagnostics.currentMicrophonePermissionState()
        if microphoneState == .notDetermined {
            requestMicrophonePermission()
        } else if microphoneState == .denied {
            recordDiagnostic("Доступ к микрофону не выдан.", severity: .warning)
        }

        if !AXIsProcessTrusted() {
            promptAccessibility()
        }

        refreshPermissionMenuItems()
        refreshIdlePresentation()
    }

    func requestMicrophonePermission() {
        diagnostics.requestMicrophoneAccess { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.recordDiagnostic(nil)
                } else {
                    self?.recordDiagnostic("Доступ к микрофону отклонён.", severity: .warning)
                    self?.openMicrophoneSettings()
                }
                self?.refreshPresentation()
            }
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

        if !AXIsProcessTrusted() {
            startPermissionPolling(watchAccessibility: true, watchMicrophone: false)
        }

        alert.runModal()
    }

    @objc func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
        startPermissionPolling(watchAccessibility: false, watchMicrophone: true)
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
            startPermissionPolling(watchAccessibility: true, watchMicrophone: false)
        }
    }

    private func startPermissionPolling(watchAccessibility: Bool, watchMicrophone: Bool) {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }

            let microphoneState = self.diagnostics.currentMicrophonePermissionState()
            self.refreshPresentation()

            let accessibilityResolved = !watchAccessibility || AXIsProcessTrusted()
            let microphoneResolved = !watchMicrophone || microphoneState != .notDetermined

            guard accessibilityResolved && microphoneResolved else { return }

            if watchMicrophone, microphoneState == .denied {
                self.recordDiagnostic("Доступ к микрофону не выдан.", severity: .warning)
            } else if watchMicrophone, microphoneState == .authorized {
                self.recordDiagnostic(nil)
            }

            if watchAccessibility, AXIsProcessTrusted() {
                timer.invalidate()
                self.recordDiagnostic(nil)
                self.promptRestart()
                return
            }

            timer.invalidate()
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
}
