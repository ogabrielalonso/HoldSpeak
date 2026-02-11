import AppKit
import Carbon.HIToolbox
import Foundation
@preconcurrency import ApplicationServices

public final class ClipboardInserter {
    public struct Snapshot: Sendable {
        fileprivate let items: [[String: Data]]
    }

    public enum InsertError: Error, Equatable {
        case accessibilityNotTrusted
        case cannotSnapshot
        case cannotSetPasteboard
        case cannotPostKeyEvent
    }

    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func snapshot() -> Snapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type.rawValue] = data
                }
            }
            return dict
        }
        return Snapshot(items: items)
    }

    public func restore(_ snapshot: Snapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let restored: [NSPasteboardItem] = snapshot.items.map { dict in
            let item = NSPasteboardItem()
            for (rawType, data) in dict {
                item.setData(data, forType: .init(rawType))
            }
            return item
        }

        _ = pasteboard.writeObjects(restored)
    }

    public func insertByPasting(text: String, restoreAfter delaySeconds: TimeInterval = 0.3) throws {
        let snapshot = snapshot()
        let pasteboardName = pasteboard.name.rawValue

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            restore(snapshot)
            throw InsertError.cannotSetPasteboard
        }

        do {
            try postCommandV()
        } catch {
            restore(snapshot)
            throw error
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
            let pb = NSPasteboard(name: .init(pasteboardName))
            let inserter = ClipboardInserter(pasteboard: pb)
            inserter.restore(snapshot)
        }
    }

    public func copyToClipboard(text: String) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw InsertError.cannotSetPasteboard
        }
    }

    private func postCommandV() throws {
        guard AXIsProcessTrusted() else {
            throw InsertError.accessibilityNotTrusted
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw InsertError.cannotPostKeyEvent
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        guard let keyDown, let keyUp else { throw InsertError.cannotPostKeyEvent }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
