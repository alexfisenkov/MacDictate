import Cocoa

enum PasteFailure: LocalizedError {
    case pasteboardWriteFailed
    case accessibilityMissing
    case eventSourceUnavailable
    case keyboardEventUnavailable

    var errorDescription: String? {
        switch self {
        case .pasteboardWriteFailed:
            return "Не удалось записать текст во временный буфер обмена."
        case .accessibilityMissing:
            return "Не удалось вставить текст: нет доступа к управлению клавиатурой."
        case .eventSourceUnavailable, .keyboardEventUnavailable:
            return "Не удалось вставить текст в активное окно."
        }
    }
}

final class PasteService {
    func paste(_ input: String) -> Result<Void, PasteFailure> {
        if input.isEmpty {
            return .success(())
        }

        let text = input + " "
        let pasteboard = NSPasteboard.general
        let oldString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return .failure(.pasteboardWriteFailed)
        }

        switch simulatePaste() {
        case .success:
            NSSound(named: "Tink")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let oldString {
                    pasteboard.clearContents()
                    pasteboard.setString(oldString, forType: .string)
                }
            }
            return .success(())

        case .failure(let error):
            if let oldString {
                pasteboard.clearContents()
                pasteboard.setString(oldString, forType: .string)
            }
            return .failure(error)
        }
    }

    private func simulatePaste() -> Result<Void, PasteFailure> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityMissing)
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failure(.eventSourceUnavailable)
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .failure(.keyboardEventUnavailable)
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        usleep(20_000)
        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)
        return .success(())
    }
}
