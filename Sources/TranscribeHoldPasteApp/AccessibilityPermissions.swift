@preconcurrency import ApplicationServices
import Foundation

enum AccessibilityPermissions {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
