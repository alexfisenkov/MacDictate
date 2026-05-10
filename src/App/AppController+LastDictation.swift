import Cocoa

extension AppController {
    @objc func copyLastDictationToClipboard() {
        guard let entry = lastDictationStore.latest() else {
            recordDiagnostic("Нет сохранённой последней диктовки.", severity: .warning)
            refreshLastDictationMenuItem()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(entry.text, forType: .string) else {
            recordDiagnostic("Не удалось скопировать последнюю диктовку в буфер обмена.", severity: .error)
            refreshLastDictationMenuItem()
            return
        }

        NSSound(named: "Tink")?.play()
        recordDiagnostic("Последняя диктовка скопирована в буфер обмена.", severity: .ok)
        refreshLastDictationMenuItem()
    }
}
