import Foundation

enum StatusPresentation {
    static func diagnosticsSummary(
        environmentIssue: EnvironmentIssue?,
        runtimeDiagnostic: RuntimeDiagnostic?
    ) -> String {
        if let environmentIssue {
            return "Диагностика: \(environmentIssue.diagnosticText)"
        }

        if let runtimeDiagnostic {
            return "Диагностика: \(runtimeDiagnostic.severity.prefix) \(runtimeDiagnostic.message)"
        }

        return "Диагностика: OK"
    }

    static func idleStatus(
        environmentIssue: EnvironmentIssue?,
        runtimeDiagnostic: RuntimeDiagnostic?
    ) -> (text: String, icon: String) {
        if let environmentIssue {
            return (environmentIssue.statusText, "⚠️")
        }

        if let runtimeDiagnostic {
            let icon: String
            switch runtimeDiagnostic.severity {
            case .ok:
                icon = ""
            case .warning:
                icon = "⚠️"
            case .error:
                icon = "🛑"
            }
            return (runtimeDiagnostic.message, icon)
        }

        return ("Ready", "")
    }

    static func accessibilityMenuTitle(isTrusted: Bool) -> String {
        isTrusted
            ? "♿️ Универсальный доступ: выдан"
            : "♿️ Универсальный доступ: не выдан"
    }

    static func microphoneMenuTitle(state: MicrophonePermissionState) -> String {
        switch state {
        case .authorized:
            return "Микрофон: доступ разрешён"
        case .notDetermined:
            return "Микрофон: ожидает подтверждения"
        case .denied:
            return "Микрофон: доступ не выдан"
        }
    }

    static func whisperModelMenuTitle(
        mode: WhisperModelMode,
        hasMaximumAccuracyModel: Bool,
        hasBalancedModel: Bool
    ) -> String {
        switch mode {
        case .balanced:
            if hasBalancedModel {
                return "Whisper: быстрая large-v3-turbo"
            }
            return "Whisper: базовая модель не скачана"
        case .maximumAccuracy:
            if hasMaximumAccuracyModel {
                return "Whisper: точная large-v3"
            }
            if hasBalancedModel {
                return "Whisper: large-v3 нужна загрузка, сейчас fallback turbo"
            }
            return "Whisper: точная модель не скачана"
        }
    }

    static func textImprovementMenuTitle(
        isEnabled: Bool,
        hasModel: Bool,
        hasRuntime: Bool
    ) -> String {
        if isEnabled, hasModel, hasRuntime {
            return "✨ Улучшение текста: включено"
        }

        if isEnabled, !hasModel {
            return "✨ Улучшение текста: нужна модель Qwen"
        }

        if isEnabled, !hasRuntime {
            return "✨ Улучшение текста: нужен компонент runtime"
        }

        if hasModel, hasRuntime {
            return "✨ Улучшение текста: выключено"
        }

        if !hasModel {
            return "✨ Улучшение текста: модель не скачана"
        }

        return "✨ Улучшение текста: нужен компонент runtime"
    }

    static func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
