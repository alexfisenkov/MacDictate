import Foundation
import Darwin

final class LicenseService {
    private static let machineIDCommandTimeout: TimeInterval = 2
    private static let machineIDCommandTerminationGrace: TimeInterval = 0.5

    private let userDefaults: UserDefaults
    private let cache: LicenseCache
    private let statusURLString: String
    private let refreshInterval: TimeInterval
    private let machineIDKey: String

    private var refreshTimer: Timer?
    private var isCheckInFlight = false

    let machineID: String
    var onChange: (() -> Void)?

    private(set) var state: LicenseState = .checking
    private(set) var runtimeDiagnostic: RuntimeDiagnostic?

    init(
        userDefaults: UserDefaults = .standard,
        cache: LicenseCache = LicenseCache(),
        statusURLString: String = "https://macdictate.pro/api/license/status",
        refreshInterval: TimeInterval = 30 * 60,
        machineIDKey: String = "MacDictateUID"
    ) {
        self.userDefaults = userDefaults
        self.cache = cache
        self.statusURLString = statusURLString
        self.refreshInterval = refreshInterval
        self.machineIDKey = machineIDKey
        self.machineID = Self.resolveMachineID(userDefaults: userDefaults, machineIDKey: machineIDKey)
    }

    deinit {
        stop()
    }

    func restoreCachedState() {
        guard let snapshot = cache.load(machineID: machineID),
              let deadline = cache.graceDeadline(for: snapshot),
              deadline > Date() else {
            state = .checking
            onChange?()
            return
        }

        state = .grace(snapshot, deadline)
        onChange?()
    }

    func startRefreshLoop() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
        refreshTimer?.tolerance = 60
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func handleWake() {
        normalizeStateIfNeeded()
        checkStatus(promoteCheckingState: !state.allowsDictation)
    }

    func normalizeStateIfNeeded() {
        switch state {
        case .grace(let snapshot, let deadline) where deadline <= Date():
            state = .serverUnavailable(snapshot)
            onChange?()
        default:
            break
        }
    }

    func checkStatus(promoteCheckingState: Bool = false) {
        guard !isCheckInFlight, let url = licenseStatusURL() else { return }

        isCheckInFlight = true
        if promoteCheckingState {
            state = .checking
            onChange?()
        } else {
            onChange?()
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.isCheckInFlight = false

                guard error == nil,
                      let data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let decoded = try? JSONDecoder().decode(LicenseStatusResponse.self, from: data) else {
                    self.handleFailure(error: error)
                    return
                }

                self.handleSuccess(response: decoded)
            }
        }.resume()
    }

    func purchaseURL() -> URL? {
        URL(string: "https://macdictate.pro/?uid=\(machineID)#pricing")
    }

    private func licenseStatusURL() -> URL? {
        var components = URLComponents(string: statusURLString)
        components?.queryItems = [URLQueryItem(name: "deviceId", value: machineID)]
        return components?.url
    }

    private func handleSuccess(response: LicenseStatusResponse) {
        let snapshot = makeSnapshot(from: response)
        runtimeDiagnostic = nil

        if snapshot.isActive {
            cache.persist(snapshot)
            state = .active(snapshot)
        } else {
            cache.persist(nil)
            state = .expired(snapshot)
        }

        onChange?()
    }

    private func handleFailure(error: Error?) {
        let cachedSnapshot = cache.load(machineID: machineID)

        if let snapshot = cachedSnapshot,
           let deadline = cache.graceDeadline(for: snapshot),
           deadline > Date() {
            state = .grace(snapshot, deadline)
        } else if case .expired(let previousExpired) = state {
            state = .expired(previousExpired)
        } else {
            state = .serverUnavailable(cachedSnapshot)
        }

        let baseMessage = "Сервер лицензий временно недоступен."
        if let error {
            runtimeDiagnostic = RuntimeDiagnostic(
                severity: .warning,
                message: "\(baseMessage) \(error.localizedDescription)"
            )
        } else {
            runtimeDiagnostic = RuntimeDiagnostic(severity: .warning, message: baseMessage)
        }

        onChange?()
    }

    private func makeSnapshot(from response: LicenseStatusResponse) -> LicenseSnapshot {
        LicenseSnapshot(
            machineID: machineID,
            isPaid: response.isPaid,
            isActive: response.isActive,
            daysLeft: response.daysLeft,
            expiresAt: Self.parseISO8601Date(response.expiresAt),
            checkedAt: Date()
        )
    }

    private static func parseISO8601Date(_ value: String?) -> Date? {
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

    static func resolveMachineID(
        userDefaults: UserDefaults,
        machineIDKey: String,
        ioregPath: String = "/usr/sbin/ioreg",
        timeoutSeconds: TimeInterval = machineIDCommandTimeout
    ) -> String {
        if let saved = userDefaults.string(forKey: machineIDKey) {
            return saved
        }

        let output = runMachineIDCommand(ioregPath: ioregPath, timeoutSeconds: timeoutSeconds)
        let uniqueID = parseMachineID(from: output) ?? "MD-\(UUID().uuidString.prefix(8))"

        userDefaults.set(uniqueID, forKey: machineIDKey)
        return uniqueID
    }

    private static func runMachineIDCommand(ioregPath: String, timeoutSeconds: TimeInterval) -> String {
        let task = Process()
        let pipe = Pipe()
        let terminationSemaphore = DispatchSemaphore(value: 0)

        task.launchPath = ioregPath
        task.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        do {
            try task.run()
        } catch {
            task.terminationHandler = nil
            return ""
        }

        if terminationSemaphore.wait(timeout: dispatchDeadline(after: timeoutSeconds)) == .timedOut {
            stopTimedOutProcess(task, terminationSemaphore: terminationSemaphore)
            task.terminationHandler = nil
            return ""
        }

        task.terminationHandler = nil

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseMachineID(from output: String) -> String? {
        if let uuidRange = output.range(of: "\"IOPlatformUUID\" = \"") {
            let substring = output[uuidRange.upperBound...]
            if let endQuote = substring.range(of: "\"") {
                let hardwareUUID = String(substring[..<endQuote.lowerBound])
                return "MD-" + hardwareUUID.prefix(8)
            }
        }

        return nil
    }

    private static func stopTimedOutProcess(_ task: Process, terminationSemaphore: DispatchSemaphore) {
        if task.isRunning {
            task.terminate()
        }

        if terminationSemaphore.wait(timeout: dispatchDeadline(after: machineIDCommandTerminationGrace)) == .success {
            return
        }

        if task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            _ = terminationSemaphore.wait(timeout: dispatchDeadline(after: 1))
        }
    }

    private static func dispatchDeadline(after seconds: TimeInterval) -> DispatchTime {
        let milliseconds = max(0, Int(seconds * 1000))
        return .now() + .milliseconds(milliseconds)
    }
}
