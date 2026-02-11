import CoreGraphics
import Foundation

enum InputMonitoringPermissions {
    static func isAllowed() -> Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    static func request() -> Bool {
        CGRequestListenEventAccess()
    }
}

