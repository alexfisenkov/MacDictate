import Foundation

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
