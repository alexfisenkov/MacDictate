import Foundation

enum StatusPresentation {
    static func licenseMenuTitle(state: LicenseState, machineID: String) -> String {
        switch state {
        case .checking:
            return "⏳ Лицензия: проверка... [\(machineID)]"
        case .active(let snapshot):
            if snapshot.isPaid {
                return "💎 Лицензия: активна [\(machineID)]"
            }
            return "🎁 Триал: \(snapshot.daysLeft) дн. [\(machineID)]"
        case .grace(let snapshot, let deadline):
            let until = shortDateTime(deadline)
            if snapshot.isPaid {
                return "🟡 Grace: лицензия до \(until) [\(machineID)]"
            }
            return "🟡 Grace: триал до \(until) [\(machineID)]"
        case .expired:
            return "🛑 Лицензия: истекла [\(machineID)]"
        case .serverUnavailable:
            return "⚠️ Лицензия: сервер недоступен [\(machineID)]"
        }
    }

    static func diagnosticsSummary(
        environmentIssue: EnvironmentIssue?,
        runtimeDiagnostic: RuntimeDiagnostic?,
        licenseState: LicenseState
    ) -> String {
        if let environmentIssue {
            return "Диагностика: \(environmentIssue.diagnosticText)"
        }

        if let runtimeDiagnostic {
            return "Диагностика: \(runtimeDiagnostic.severity.prefix) \(runtimeDiagnostic.message)"
        }

        switch licenseState {
        case .grace(_, let deadline):
            return "Диагностика: offline grace активен до \(shortDateTime(deadline))."
        case .checking:
            return "Диагностика: выполняется проверка лицензии."
        case .serverUnavailable:
            return "Диагностика: сервер лицензий недоступен."
        case .expired:
            return "Диагностика: лицензия истекла."
        case .active:
            return "Диагностика: OK"
        }
    }

    static func idleStatus(
        environmentIssue: EnvironmentIssue?,
        runtimeDiagnostic: RuntimeDiagnostic?,
        licenseState: LicenseState
    ) -> (text: String, icon: String) {
        if let environmentIssue {
            return (environmentIssue.statusText, "⚠️")
        }

        if let runtimeDiagnostic {
            let icon: String
            switch runtimeDiagnostic.severity {
            case .ok:
                icon = "🎙️"
            case .warning:
                icon = "⚠️"
            case .error:
                icon = "🛑"
            }
            return (runtimeDiagnostic.message, icon)
        }

        switch licenseState {
        case .checking:
            return ("Checking license...", "⏳")
        case .active:
            return ("Ready", "🎙️")
        case .grace:
            return ("Offline Grace", "🟡")
        case .expired:
            return ("License Expired", "🛑")
        case .serverUnavailable:
            return ("License Server Unavailable", "⚠️")
        }
    }

    static func accessibilityMenuTitle(isTrusted: Bool) -> String {
        isTrusted
            ? "♿️ Универсальный доступ: выдан"
            : "♿️ Универсальный доступ: не выдан"
    }

    static func microphoneMenuTitle(state: MicrophonePermissionState) -> String {
        switch state {
        case .authorized:
            return "🎤 Микрофон: доступ разрешён"
        case .notDetermined:
            return "🎤 Микрофон: ожидает подтверждения"
        case .denied:
            return "🎤 Микрофон: доступ не выдан"
        }
    }

    static func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
