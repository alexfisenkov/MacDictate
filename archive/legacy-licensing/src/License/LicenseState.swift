import Foundation

enum LicenseState {
    case checking
    case active(LicenseSnapshot)
    case grace(LicenseSnapshot, Date)
    case expired(LicenseSnapshot?)
    case serverUnavailable(LicenseSnapshot?)

    var snapshot: LicenseSnapshot? {
        switch self {
        case .checking:
            return nil
        case .active(let snapshot):
            return snapshot
        case .grace(let snapshot, _):
            return snapshot
        case .expired(let snapshot):
            return snapshot
        case .serverUnavailable(let snapshot):
            return snapshot
        }
    }

    var allowsDictation: Bool {
        switch self {
        case .active, .grace:
            return true
        case .checking, .expired, .serverUnavailable:
            return false
        }
    }
}
