import AppKit
import ApplicationServices
import Carbon

private let inputTapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<InputBlocker>.fromOpaque(context).takeUnretainedValue()
    return blocker.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
}

/// All state is confined to the main run loop, including the event tap.
/// Never perform disk IO, layout translation, or UI work in the callback.
final class InputBlocker {
    private(set) var mode = InputMode.unlocked
    var onModeChange: ((InputMode) -> Void)?
    var onFailure: ((String) -> Void)?

    private var settings: AppSettings
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var configuring = false
    private var recentKeys: [KeyStroke] = []
    private var forwardedKeys = Set<UInt16>()
    private var forwardedModifiers = Set<UInt16>()
    private var suppressedKeys = Set<UInt16>()
    private var forwardedButtons = Set<UInt32>()
    private var suppressedButtons = Set<UInt32>()
    private var cursorAnchor: CGPoint?
    private var lastActivity = ProcessInfo.processInfo.systemUptime
    private static let releaseTag: Int64 = 0x5041444C4F434B

    init(settings: AppSettings) {
        self.settings = settings
        recentKeys.reserveCapacity(10)
    }

    var isRunning: Bool {
        guard let tap else { return false }
        return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        stop()
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { return false }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask.max, callback: inputTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        else { return false }

        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        resetActivity()
        return isRunning
    }

    func stop() {
        setMode(.unlocked)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        source = nil
        tap = nil
        recentKeys.removeAll(keepingCapacity: true)
        forwardedKeys.removeAll()
        forwardedModifiers.removeAll()
        suppressedKeys.removeAll()
        forwardedButtons.removeAll()
        suppressedButtons.removeAll()
    }

    func update(settings: AppSettings) {
        self.settings = settings
        recentKeys.removeAll(keepingCapacity: true)
        resetActivity()
    }

    func setConfiguring(_ active: Bool) {
        configuring = active
        recentKeys.removeAll(keepingCapacity: true)
        resetActivity()
    }

    func resetActivity() { lastActivity = ProcessInfo.processInfo.systemUptime }

    @discardableResult
    func setMode(_ newMode: InputMode) -> Bool {
        if newMode != .unlocked {
            guard isRunning, !configuring, !IsSecureEventInputEnabled() else { return false }
        }
        guard newMode != mode else { return true }
        if newMode != .unlocked {
            if mode == .unlocked { cursorAnchor = CGEvent(source: nil)?.location }
            releaseForwardedInputs()
        } else {
            cursorAnchor = nil
        }
        mode = newMode
        recentKeys.removeAll(keepingCapacity: true)
        resetActivity()
        // Consumers must dispatch UI updates out of this callback.
        onModeChange?(newMode)
        return true
    }

    func checkIdle() {
        guard mode == .unlocked, !configuring, settings.autoLockMinutes > 0,
              isRunning, !IsSecureEventInputEnabled() else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - lastActivity
        // The system clock also sees protected input that may bypass our tap.
        let systemIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        if min(elapsed, systemIdle) >= Double(settings.autoLockMinutes) * 60 {
            setMode(.locked)
        }
    }

    /// Return true to discard an event.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            setMode(.unlocked)
            if type == .tapDisabledByTimeout, let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            onFailure?("Input filtering was interrupted. Padlock returned to Default mode.")
            return false
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.releaseTag { return false }
        // Null events are not user activity and must not postpone idle locking.
        if type == .null { return false }
        if mode == .unlocked { resetActivity() }

        if type == .keyDown || type == .keyUp {
            return handleKey(type: type, event: event)
        }
        if type == .flagsChanged { return handleModifier(event) }

        if mode != .unlocked, let anchor = cursorAnchor {
            switch type {
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .tabletPointer:
                // A session tap can discard movement after WindowServer has
                // adjusted the visible cursor. Pin it without generating a
                // replacement event; no root-only HID tap is needed.
                event.location = anchor
                CGWarpMouseCursorPosition(anchor)
            default: break
            }
        }

        if let button = mouseButton(for: type, event: event) {
            let down = type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown
            if !down, suppressedButtons.remove(button) != nil { return true }
            if mode != .unlocked {
                if down { suppressedButtons.insert(button) }
                return true
            }
            if down { forwardedButtons.insert(button) } else { forwardedButtons.remove(button) }
            return false
        }
        // Mouse movement, dragging, scroll, tablet, media keys, and any other
        // event the session tap delivers are blocked in either blocking mode.
        return mode != .unlocked
    }

    private func handleKey(type: CGEventType, event: CGEvent) -> Bool {
        let stroke = KeyStroke(event: event)
        let code = stroke.keyCode
        if type == .keyUp {
            if suppressedKeys.remove(code) != nil { return true }
            if forwardedKeys.remove(code) != nil { return false }
            return mode != .unlocked
        }

        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if stroke == .emergency {
            setMode(.unlocked)
            suppressedKeys.insert(code)
            return true
        }
        // A key pressed while locked must be released before it can begin a
        // new keystroke after unlocking, including autorepeat.
        if suppressedKeys.contains(code) { return true }

        if !configuring, !repeating {
            recentKeys.append(stroke)
            if recentKeys.count > 10 { recentKeys.removeFirst() }
            var target: InputMode?
            if mode != .unlocked, recentKeys.suffix(settings.unlockSequence.count)
                .elementsEqual(settings.unlockSequence) {
                target = .unlocked
            } else if mode != .locked, recentKeys.suffix(settings.lockSequence.count)
                .elementsEqual(settings.lockSequence) {
                target = .locked
            } else if mode == .unlocked, recentKeys.suffix(settings.restrictSequence.count)
                .elementsEqual(settings.restrictSequence) {
                target = .restricted
            }
            if let target, setMode(target) {
                suppressedKeys.insert(code)
                return true
            }
        }

        let prohibited = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskCommand.rawValue
        let restrictedAllows = mode == .restricted && stroke.modifiers & prohibited == 0
            && (KeyboardLayout.isAlphanumeric(code) || KeyboardLayout.navigationCodes.contains(code))
        if mode == .unlocked || restrictedAllows {
            forwardedKeys.insert(code)
            return false
        }
        suppressedKeys.insert(code)
        return true
    }

    private func handleModifier(_ event: CGEvent) -> Bool {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flag: CGEventFlags
        switch code {
        case 54, 55: flag = .maskCommand
        case 56, 60: flag = .maskShift
        case 58, 61: flag = .maskAlternate
        case 59, 62: flag = .maskControl
        case 57: flag = .maskAlphaShift
        case 63: flag = .maskSecondaryFn
        default: return mode != .unlocked
        }
        let isPressed = event.flags.contains(flag)
        if mode == .unlocked || (mode == .restricted && flag == .maskShift) {
            if isPressed { forwardedModifiers.insert(code) } else { forwardedModifiers.remove(code) }
            return false
        }
        // Releases must reach applications even when the corresponding press
        // preceded activation, so Option/Command/Control cannot remain stuck.
        if !isPressed {
            forwardedModifiers.remove(code)
            event.flags.subtract([.maskCommand, .maskControl, .maskAlternate])
            if mode == .locked { event.flags.remove(.maskShift) }
            return false
        }
        return true
    }

    private func mouseButton(for type: CGEventType, event: CGEvent) -> UInt32? {
        switch type {
        case .leftMouseDown, .leftMouseUp: return 0
        case .rightMouseDown, .rightMouseUp: return 1
        case .otherMouseDown, .otherMouseUp:
            return UInt32(clamping: event.getIntegerValueField(.mouseEventButtonNumber))
        default: return nil
        }
    }

    private func releaseForwardedInputs() {
        for code in forwardedKeys.union(forwardedModifiers) {
            if let release = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
                release.flags = []
                release.setIntegerValueField(.eventSourceUserData, value: Self.releaseTag)
                release.post(tap: .cgSessionEventTap)
            }
        }
        suppressedKeys.formUnion(forwardedKeys)
        forwardedKeys.removeAll()
        forwardedModifiers.removeAll()

        let location = CGEvent(source: nil)?.location ?? .zero
        for button in forwardedButtons {
            let up: CGEventType = button == 0 ? .leftMouseUp : (button == 1 ? .rightMouseUp : .otherMouseUp)
            if let mouseButton = CGMouseButton(rawValue: button),
               let release = CGEvent(mouseEventSource: nil, mouseType: up,
                                     mouseCursorPosition: location, mouseButton: mouseButton) {
                release.flags = []
                release.setIntegerValueField(.eventSourceUserData, value: Self.releaseTag)
                release.post(tap: .cgSessionEventTap)
            }
        }
        suppressedButtons.formUnion(forwardedButtons)
        forwardedButtons.removeAll()
    }
}
