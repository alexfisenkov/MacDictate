import Cocoa

final class HotkeyMonitor {
    private let isRecording: () -> Bool
    private let isProcessing: () -> Bool
    private let onStartRequest: () -> Void
    private let onStopRequest: () -> Void

    private var monitorToken: Any?
    private var lastOptionPressTime: TimeInterval = 0

    init(
        isRecording: @escaping () -> Bool,
        isProcessing: @escaping () -> Bool,
        onStartRequest: @escaping () -> Void,
        onStopRequest: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.isProcessing = isProcessing
        self.onStartRequest = onStartRequest
        self.onStopRequest = onStopRequest
    }

    deinit {
        stop()
    }

    func start() {
        guard monitorToken == nil else { return }

        monitorToken = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            guard event.keyCode == 58 else { return }
            guard event.modifierFlags.contains(.option) else { return }

            let now = Date().timeIntervalSince1970

            if self.isRecording() {
                self.onStopRequest()
                self.lastOptionPressTime = now
                return
            }

            if self.isProcessing() {
                self.lastOptionPressTime = now
                return
            }

            let isDoublePress = now - self.lastOptionPressTime < 0.4
            self.lastOptionPressTime = now

            if isDoublePress {
                self.onStartRequest()
            }
        }
    }

    func stop() {
        if let monitorToken {
            NSEvent.removeMonitor(monitorToken)
            self.monitorToken = nil
        }
    }
}
