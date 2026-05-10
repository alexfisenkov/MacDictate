import Foundation
import ServiceManagement

if #available(macOS 13.0, *) {
    do {
        print("Status before: \(SMAppService.mainApp.status.rawValue)")
        try SMAppService.mainApp.register()
        print("Successfully registered login item!")
        print("Status after: \(SMAppService.mainApp.status.rawValue)")
        try SMAppService.mainApp.unregister()
    } catch {
        print("Failed to register: \(error)")
    }
}
