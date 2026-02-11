import CoreGraphics
import Carbon.HIToolbox
import Foundation
#if canImport(AppKit)
import AppKit
#endif

private let thpCarbonHotKeySignature: OSType = 0x54485031 // "THP1"

private func thpCarbonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ eventRef: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }

    let monitor = Unmanaged<PressAndHoldHotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()

    var incoming = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &incoming
    )
    guard status == noErr else { return status }
    guard incoming.signature == thpCarbonHotKeySignature else { return OSStatus(eventNotHandledErr) }
    guard incoming.id == monitor.carbonHotKeyID else { return OSStatus(eventNotHandledErr) }

    let kind = GetEventKind(eventRef)
    if kind == UInt32(kEventHotKeyPressed) {
        monitor.transitionToHeldIfNeeded()
        return noErr
    }
    if kind == UInt32(kEventHotKeyReleased) {
        monitor.transitionToReleasedIfNeeded()
        return noErr
    }

    return OSStatus(eventNotHandledErr)
}

public final class PressAndHoldHotkeyMonitor {
    public struct Hotkey: Sendable {
        public var requiredFlags: CGEventFlags
        public var keyCode: CGKeyCode?

        public init(requiredFlags: CGEventFlags = [], keyCode: CGKeyCode? = nil) {
            self.requiredFlags = requiredFlags
            self.keyCode = keyCode
        }

        public static var functionKey: Hotkey {
            Hotkey(keyCode: CGKeyCode(kVK_Function))
        }

        public static var controlOptionSpace: Hotkey {
            Hotkey(requiredFlags: [.maskControl, .maskAlternate], keyCode: CGKeyCode(kVK_Space))
        }

        public static var controlOptionV: Hotkey {
            Hotkey(requiredFlags: [.maskControl, .maskAlternate], keyCode: CGKeyCode(kVK_ANSI_V))
        }

        public static var controlOptionD: Hotkey {
            Hotkey(requiredFlags: [.maskControl, .maskAlternate], keyCode: CGKeyCode(kVK_ANSI_D))
        }

        public static var controlOptionReturn: Hotkey {
            Hotkey(requiredFlags: [.maskControl, .maskAlternate], keyCode: CGKeyCode(kVK_Return))
        }

        public static var controlOptionCommandSpace: Hotkey {
            Hotkey(requiredFlags: [.maskControl, .maskAlternate, .maskCommand], keyCode: CGKeyCode(kVK_Space))
        }
    }

    public enum MonitorError: Error {
        case tapCreationFailed
        case hotKeyRegistrationFailed(OSStatus)
    }

    private let hotkey: Hotkey
    private let onPressed: @Sendable () -> Void
    private let onReleased: @Sendable () -> Void
    fileprivate let carbonHotKeyID: UInt32

    private let lock = NSLock()
    private var isHeld = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
#if canImport(AppKit)
    private var globalFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
#endif
    private var carbonHandler: EventHandlerRef?
    private var carbonHotKeyRef: EventHotKeyRef?

    public init(
        hotkey: Hotkey = .functionKey,
        carbonHotKeyID: UInt32 = 1,
        onPressed: @escaping @Sendable () -> Void,
        onReleased: @escaping @Sendable () -> Void
    ) {
        self.hotkey = hotkey
        self.carbonHotKeyID = carbonHotKeyID
        self.onPressed = onPressed
        self.onReleased = onReleased
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard eventTap == nil, carbonHandler == nil, carbonHotKeyRef == nil else { return }

        if shouldUseCarbonHotKey {
            try startCarbonHotKey()
            return
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let monitor = Unmanaged<PressAndHoldHotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            throw MonitorError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source

#if canImport(AppKit)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event: event)
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handle(event: event)
        }
#endif
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
#if canImport(AppKit)
        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
        }
        globalFlagsMonitor = nil
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        globalKeyMonitor = nil
#endif

        if let carbonHotKeyRef {
            UnregisterEventHotKey(carbonHotKeyRef)
        }
        carbonHotKeyRef = nil

        if let carbonHandler {
            RemoveEventHandler(carbonHandler)
        }
        carbonHandler = nil

        lock.lock()
        isHeld = false
        lock.unlock()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        if let keyCode = hotkey.keyCode {
            let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            guard eventKeyCode == keyCode else { return }
            if !hotkey.requiredFlags.isEmpty, !event.flags.contains(hotkey.requiredFlags) { return }

            if type == .keyDown {
                transitionToHeldIfNeeded()
            } else if type == .keyUp {
                transitionToReleasedIfNeeded()
            }
            return
        }

        if !hotkey.requiredFlags.isEmpty {
            let flags = event.flags
            let heldNow = flags.contains(hotkey.requiredFlags)

            if heldNow {
                transitionToHeldIfNeeded()
            } else {
                transitionToReleasedIfNeeded()
            }
        }
    }

#if canImport(AppKit)
    private func handle(event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            guard let keyCode = hotkey.keyCode, keyCode == CGKeyCode(kVK_Function) else { return }
            let heldNow = event.modifierFlags.contains(.function)
            heldNow ? transitionToHeldIfNeeded() : transitionToReleasedIfNeeded()
        case .keyDown, .keyUp:
            guard let keyCode = hotkey.keyCode else { return }
            guard event.keyCode == UInt16(keyCode) else { return }
            if !requiredModifierFlagsSatisfied(event.modifierFlags) { return }
            if event.type == .keyDown {
                if event.isARepeat { return }
                transitionToHeldIfNeeded()
            } else {
                transitionToReleasedIfNeeded()
            }
        default:
            return
        }
    }

    private func requiredModifierFlagsSatisfied(_ flags: NSEvent.ModifierFlags) -> Bool {
        if hotkey.requiredFlags.contains(.maskControl), !flags.contains(.control) { return false }
        if hotkey.requiredFlags.contains(.maskAlternate), !flags.contains(.option) { return false }
        if hotkey.requiredFlags.contains(.maskShift), !flags.contains(.shift) { return false }
        if hotkey.requiredFlags.contains(.maskCommand), !flags.contains(.command) { return false }
        return true
    }
#endif

    private var shouldUseCarbonHotKey: Bool {
        guard let keyCode = hotkey.keyCode else { return false }
        if keyCode == CGKeyCode(kVK_Function) { return false }
        return true
    }

    private func startCarbonHotKey() throws {
        guard let keyCode = hotkey.keyCode else { return }

        let hotKeyID = EventHotKeyID(signature: thpCarbonHotKeySignature, id: carbonHotKeyID)

        let handler: EventHandlerUPP = thpCarbonHotKeyHandler

        var eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        // Use the dispatcher target so the hotkey can fire even if the app has no key window.
        let target = GetEventDispatcherTarget()
        let installStatus = InstallEventHandler(target, handler, eventSpecs.count, &eventSpecs, refcon, &handlerRef)
        guard installStatus == noErr else { throw MonitorError.hotKeyRegistrationFailed(installStatus) }
        carbonHandler = handlerRef

        var modifiers: UInt32 = 0
        if hotkey.requiredFlags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if hotkey.requiredFlags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if hotkey.requiredFlags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if hotkey.requiredFlags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }

        var hotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, target, 0, &hotKeyRef)
        guard registerStatus == noErr, let hotKeyRef else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            carbonHandler = nil
            throw MonitorError.hotKeyRegistrationFailed(registerStatus)
        }
        carbonHotKeyRef = hotKeyRef
    }

    fileprivate func transitionToHeldIfNeeded() {
        let shouldFire: Bool
        lock.lock()
        if isHeld {
            shouldFire = false
        } else {
            isHeld = true
            shouldFire = true
        }
        lock.unlock()

        guard shouldFire else { return }
        let onPressed = self.onPressed
        DispatchQueue.main.async(execute: onPressed)
    }

    fileprivate func transitionToReleasedIfNeeded() {
        let shouldFire: Bool
        lock.lock()
        if isHeld {
            isHeld = false
            shouldFire = true
        } else {
            shouldFire = false
        }
        lock.unlock()

        guard shouldFire else { return }
        let onReleased = self.onReleased
        DispatchQueue.main.async(execute: onReleased)
    }
}
