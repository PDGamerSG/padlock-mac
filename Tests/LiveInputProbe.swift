// Opt-in end-to-end probe for the packaged app. It never records user input.
// Run only during an authorized interactive test session; this briefly blocks
// input. A separate watchdog terminates the target app if this probe stalls.
import AppKit
import ApplicationServices
import Carbon

private let eventTag: Int64 = 0x504C515450524F42
private let releaseTag: Int64 = 0x5041444C4F434B
private var passed = 0
private var failed = 0
private enum ProbeError: Error { case blocked(String) }
private struct ProbeStroke: Decodable {
    let keyCode: UInt16
    let modifiers: UInt64
}
private struct ProbeSettings: Decodable {
    let unlockSequence: [ProbeStroke]
    let restrictSequence: [ProbeStroke]
    let lockSequence: [ProbeStroke]
}
private func desktopIsUnlocked() -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return !(session["CGSSessionScreenIsLocked"] as? Bool ?? false)
}

func pump(_ seconds: TimeInterval = 0.14) {
    let until = Date().addingTimeInterval(seconds)
    while Date() < until {
        if let event = NSApp.nextEvent(matching: .any, until: until, inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }
    }
}

func ax(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}
func elements(_ element: AXUIElement, _ key: String) -> [AXUIElement] {
    ax(element, key) as? [AXUIElement] ?? []
}
func strings(_ element: AXUIElement, depth: Int = 0) -> [String] {
    guard depth < 10 else { return [] }
    var result = ["AXTitle", "AXValue", "AXDescription"].compactMap { ax(element, $0) as? String }
    for child in elements(element, "AXChildren") { result += strings(child, depth: depth + 1) }
    return result
}

struct CapturedInput {
    let type: NSEvent.EventType
    let key: UInt16
    let flags: NSEvent.ModifierFlags
    let tag: Int64
}
final class ProbeView: NSView {
    var received: [CapturedInput] = []
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let text = "Padlock verification\nTemporary input target. No personal input is recorded."
        (text as NSString).draw(in: bounds.insetBy(dx: 24, dy: 24), withAttributes: [
            .font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.labelColor
        ])
    }
    func capture(_ event: NSEvent) {
        let tag = event.cgEvent?.getIntegerValueField(.eventSourceUserData) ?? 0
        guard tag == eventTag || tag == releaseTag else { return }
        received.append(CapturedInput(type: event.type,
            key: [.keyDown, .keyUp, .flagsChanged].contains(event.type) ? event.keyCode : 0,
            flags: event.modifierFlags, tag: tag))
    }
    override func keyDown(with event: NSEvent) { capture(event) }
    override func keyUp(with event: NSEvent) { capture(event) }
    override func flagsChanged(with event: NSEvent) { capture(event) }
    override func mouseDown(with event: NSEvent) { capture(event) }
    override func mouseUp(with event: NSEvent) { capture(event) }
    override func rightMouseDown(with event: NSEvent) { capture(event) }
    override func rightMouseUp(with event: NSEvent) { capture(event) }
    override func otherMouseDown(with event: NSEvent) { capture(event) }
    override func otherMouseUp(with event: NSEvent) { capture(event) }
    override func mouseMoved(with event: NSEvent) { capture(event) }
    override func mouseDragged(with event: NSEvent) { capture(event) }
    override func scrollWheel(with event: NSEvent) { capture(event) }
}

@main enum LiveInputProbe {
    static func main() {
        do { try execute() }
        catch ProbeError.blocked(let reason) { print("BLOCKED: \(reason)"); exit(2) }
        catch { print("LIVE VALIDATION FAILED: \(error)"); exit(1) }
    }
    static func execute() throws {
        guard desktopIsUnlocked() else {
            throw ProbeError.blocked("unlock the desktop before running interactive checks")
        }
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            throw ProbeError.blocked("test driver lacks Accessibility/event posting access")
        }
        guard let target = NSRunningApplication.runningApplications(
            withBundleIdentifier: "io.github.pdgamersg.padlock").first else {
            throw ProbeError.blocked("start the packaged Padlock app first")
        }
        let appElement = AXUIElementCreateApplication(target.processIdentifier)
        let prefs = UserDefaults(suiteName: "io.github.pdgamersg.padlock")!
        guard let saved = prefs.data(forKey: "Padlock.settings.v1") else {
            throw ProbeError.blocked("open Settings once so the current sequences can be read")
        }
        let configuration = try JSONDecoder().decode(ProbeSettings.self, from: saved)
        guard configuration.restrictSequence.count == 1,
              configuration.restrictSequence[0].keyCode == 15,
              configuration.restrictSequence[0].modifiers == CGEventFlags.maskAlternate.rawValue,
              configuration.lockSequence.count == 1,
              configuration.lockSequence[0].keyCode == 37,
              configuration.lockSequence[0].modifiers == CGEventFlags.maskAlternate.rawValue else {
            throw ProbeError.blocked("this probe requires Option+R/Option+L mode shortcuts")
        }

        // If input recovery or this process stalls, only this exact target PID
        // is terminated. No privacy permissions or persistent cursor settings
        // are modified by the watchdog.
        let watchdog = Process()
        watchdog.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        watchdog.arguments = ["-c", "import os,signal,time; time.sleep(150); os.kill(int(__import__('sys').argv[1]), signal.SIGTERM)", String(target.processIdentifier)]
        try watchdog.run()
        defer { if watchdog.isRunning { watchdog.terminate() } }

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 220, width: 620, height: 330),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Padlock verification — temporary input target"
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        let probe = ProbeView(frame: NSRect(x: 0, y: 0, width: 620, height: 330))
        window.contentView = probe
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(probe)
        app.activate(ignoringOtherApps: true)
        pump(0.5)

        func mode() -> String {
            if let extras = ax(appElement, "AXExtrasMenuBar") {
                for value in strings(extras as! AXUIElement) {
                    for name in ["Default", "Restricted", "Locked"] where value.hasPrefix("Padlock, \(name).") {
                        return name
                    }
                }
            }
            for panel in elements(appElement, "AXWindows") {
                let title = ax(panel, "AXTitle") as? String ?? ""
                if title == "Padlock Settings" { continue }
                for text in strings(panel) where ["Default", "Restricted", "Locked"].contains(text) { return text }
            }
            return "unknown"
        }

        func check(_ name: String, _ predicate: @autoclosure () -> Bool, _ details: String = "") {
            if predicate() { passed += 1; print("PASS \(name) \(details)") }
            else { failed += 1; print("FAIL \(name) [mode=\(mode())] \(details)") }
            fflush(stdout)
        }

        func focus() -> Bool {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(probe)
            app.activate(ignoringOtherApps: true)
            pump(0.08)
            return NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        }

        let source = CGEventSource(stateID: .privateState)!
        func postKey(_ code: UInt16, down: Bool, flags: CGEventFlags = [], repeating: Bool = false) {
            guard desktopIsUnlocked() else { return }
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)!
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.setIntegerValueField(.keyboardEventAutorepeat, value: repeating ? 1 : 0)
            event.post(tap: .cgSessionEventTap)
            pump(0.025)
        }
        func key(_ code: UInt16, flags: CGEventFlags = [], repeating: Bool = false) {
            postKey(code, down: true, flags: flags, repeating: repeating)
            postKey(code, down: false, flags: flags)
        }
        func unlock() {
            for stroke in configuration.unlockSequence {
                key(stroke.keyCode, flags: CGEventFlags(rawValue: stroke.modifiers))
            }
            pump()
        }
        func emergency() { key(53, flags: [.maskControl, .maskAlternate, .maskCommand]); pump() }
        func keyDowns() -> [UInt16] { probe.received.filter { $0.tag == eventTag && $0.type == .keyDown }.map(\.key) }
        func clear() { probe.received.removeAll() }
        func pointer(_ type: CGEventType, at location: CGPoint, button: CGMouseButton = .left) {
            guard desktopIsUnlocked() else { return }
            let event = CGEvent(mouseEventSource: source, mouseType: type,
                                mouseCursorPosition: location, mouseButton: button)!
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cgSessionEventTap)
            pump(0.06)
        }
        func scroll() {
            guard desktopIsUnlocked() else { return }
            let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1,
                                wheel1: 12, wheel2: 0, wheel3: 0)!
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cgSessionEventTap)
            pump(0.1)
        }

        defer { if mode() != "Default" { emergency() }; window.close() }
        guard focus() else { throw ProbeError.blocked("could not focus isolated probe window") }
        print("Target PID \(target.processIdentifier); initial mode \(mode()); watchdog armed")
        check("starts in Default", mode() == "Default")

        // Settings is intentionally still open for this first case.
        guard elements(appElement, "AXWindows").contains(where: {
            ax($0, "AXTitle") as? String == "Padlock Settings"
        }) else { throw ProbeError.blocked("open Padlock Settings before starting this probe") }
        clear(); key(37, flags: .maskAlternate); pump()
        check("Settings pauses lock sequence", mode() == "Default" && keyDowns() == [37])
        for settings in elements(appElement, "AXWindows") where ax(settings, "AXTitle") as? String == "Padlock Settings" {
            if let close = ax(settings, "AXCloseButton") {
                _ = AXUIElementPerformAction(close as! AXUIElement, "AXPress" as CFString)
            }
        }
        pump(); _ = focus()
        guard !IsSecureEventInputEnabled() else {
            throw ProbeError.blocked("another application holds Secure Keyboard Entry")
        }

        if CommandLine.arguments.contains("--held-stress") {
            for iteration in 1...25 {
                clear(); postKey(7, down: true); key(37, flags: .maskAlternate)
                let firstLocked = mode() == "Locked"
                postKey(7, down: false); unlock()
                let firstUnlocked = mode() == "Default"
                key(37, flags: .maskAlternate); postKey(7, down: true); unlock()
                let unlocked = mode() == "Default"
                clear(); postKey(7, down: true, repeating: true); postKey(7, down: false)
                let repeatSuppressed = keyDowns().isEmpty
                clear(); key(7)
                check("held-key transition stress \(iteration)", firstLocked && firstUnlocked && unlocked && repeatSuppressed && keyDowns() == [7],
                      "firstLocked=\(firstLocked) firstUnlocked=\(firstUnlocked) unlocked=\(unlocked) repeatSuppressed=\(repeatSuppressed) keys=\(keyDowns()) front=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)")
                if !unlocked { emergency() }
            }
            print("LIVE STRESS RESULT: \(passed) passed, \(failed) failed")
            if failed > 0 { throw NSError(domain: "Padlock.LiveValidation.Stress", code: failed) }
            return
        }

        clear()
        let baseline: [UInt16] = [0, 24, 36, 48, 51, 123, 122]
        for code in baseline { key(code) }
        check("Default forwards letters, punctuation, editing, navigation, function keys", keyDowns() == baseline)

        let screenHeight = NSScreen.screens[0].frame.height
        let center = CGPoint(x: window.frame.midX, y: screenHeight - window.frame.midY)
        pointer(.mouseMoved, at: center)
        clear(); pointer(.leftMouseDown, at: center); pointer(.leftMouseUp, at: center); scroll()
        check("Default forwards clicks and scroll", probe.received.contains { $0.type == .leftMouseDown }
              && probe.received.contains { $0.type == .leftMouseUp }
              && probe.received.contains { $0.type == .scrollWheel })

        clear(); key(37, flags: .maskAlternate, repeating: true); pump()
        check("autorepeat cannot trigger a mode change", mode() == "Default")
        clear(); key(15, flags: .maskAlternate); pump()
        check("Option+R enters Restricted and consumes trigger", mode() == "Restricted" && keyDowns().isEmpty)
        guard mode() == "Restricted" else {
            throw NSError(domain: "Padlock.LiveValidation.RestrictActivation", code: 1)
        }

        let allowed: [UInt16] = [46,45,40,38,37,35,34,32,31,29,28,26,25,23,22,21,20,19,18,
            17,16,15,14,13,12,11,9,8,7,6,5,4,3,2,1,0,82,83,84,85,86,87,88,89,91,92,
            49,115,116,119,121,123,124,125,126]
        clear(); for code in allowed { key(code) }
        check("Restricted permits all documented alphanumeric/keypad/navigation keys", mode() == "Restricted" && keyDowns() == allowed)
        clear(); key(0, flags: .maskShift); key(18, flags: .maskShift)
        check("Restricted permits Shift combinations", keyDowns() == [0,18])
        clear(); for flags: CGEventFlags in [.maskControl, .maskAlternate, .maskCommand] { key(7, flags: flags) }
        check("Restricted blocks Control, Option, and Command shortcuts", keyDowns().isEmpty)
        let denied: [UInt16] = [24,27,30,33,36,39,41,42,43,44,47,48,50,51,53,65,67,69,71,75,76,78,81,96,122]
        clear(); for code in denied { key(code) }
        check("Restricted blocks editing, punctuation, and function keys", keyDowns().isEmpty)

        let anchor = CGEvent(source: nil)!.location
        clear(); pointer(.mouseMoved, at: CGPoint(x: anchor.x + 35, y: anchor.y + 25))
        pointer(.leftMouseDown, at: anchor); pointer(.leftMouseUp, at: anchor); scroll()
        let afterMove = CGEvent(source: nil)!.location
        check("Restricted blocks pointer input", probe.received.isEmpty)
        check("Restricted pins visible cursor", abs(afterMove.x - anchor.x) < 2 && abs(afterMove.y - anchor.y) < 2,
              "anchor=\(anchor) actual=\(afterMove)")

        for code: UInt16 in [0,1,7,2,3] { key(code) }
        check("mistyped unlock sequence stays Restricted", mode() == "Restricted")
        clear(); unlock()
        check("configured sequence unlocks Restricted and consumes final key", mode() == "Default")

        clear(); key(37, flags: .maskAlternate); pump()
        check("Option+L enters Locked and consumes trigger", mode() == "Locked" && keyDowns().isEmpty)
        guard mode() == "Locked" else {
            throw NSError(domain: "Padlock.LiveValidation.LockActivation", code: 1)
        }
        clear(); for code in allowed { key(code) }; for code in denied { key(code) }
        for flags: CGEventFlags in [.maskControl, .maskAlternate, .maskCommand, .maskShift] { key(7, flags: flags) }
        check("Locked blocks letters, navigation, editing, functions, and shortcuts", keyDowns().isEmpty && mode() == "Locked")
        clear(); pointer(.mouseMoved, at: center); pointer(.leftMouseDown, at: center)
        pointer(.leftMouseUp, at: center); scroll()
        check("Locked blocks pointer input", probe.received.isEmpty)
        for code: UInt16 in [0,1,2,3] { key(code, flags: .maskShift) }
        check("wrong-modifier unlock is rejected", mode() == "Locked")
        clear(); key(0); key(0); unlock()
        check("unlock recovers after overlapping partial sequence", mode() == "Default" && keyDowns().isEmpty)

        key(15, flags: .maskAlternate); key(37, flags: .maskAlternate); pump()
        check("Restricted escalates to Locked", mode() == "Locked")
        emergency(); check("fixed emergency sequence unlocks", mode() == "Default")

        clear(); postKey(7, down: true); key(37, flags: .maskAlternate); pump()
        check("activation releases already-forwarded held keys", probe.received.contains { $0.type == .keyUp && $0.key == 7 && $0.tag == releaseTag })
        postKey(7, down: false); unlock()
        check("unlock after forwarded key release", mode() == "Default", "secure=\(IsSecureEventInputEnabled())")
        key(37, flags: .maskAlternate)
        check("held-key test starts Locked", mode() == "Locked")
        postKey(7, down: true); unlock()
        check("unlock while a blocked key is held", mode() == "Default", "secure=\(IsSecureEventInputEnabled())")
        clear(); postKey(7, down: true, repeating: true); postKey(7, down: false)
        check("held blocked key cannot leak autorepeat after unlock", keyDowns().isEmpty && mode() == "Default")
        clear(); key(7)
        check("key works again after its physical release", keyDowns() == [7],
              "received=\(probe.received.map { "\($0.type.rawValue):\($0.key):\($0.tag)" }) secure=\(IsSecureEventInputEnabled())")

        key(37, flags: .maskAlternate); pump()
        let secureResult = EnableSecureEventInput()
        pump(1.6)
        check("Secure Keyboard Entry fails open", secureResult == noErr && mode() == "Default")
        if secureResult == noErr { DisableSecureEventInput() }
        pump(1.3)
        key(37, flags: .maskAlternate); pump()
        check("filtering resumes after Secure Keyboard Entry ends", mode() == "Locked")
        emergency()
        check("final recovery leaves input enabled", mode() == "Default")
        print("LIVE RESULT: \(passed) passed, \(failed) failed")
        fflush(stdout)
        if failed > 0 { throw NSError(domain: "Padlock.LiveValidation", code: failed) }
    }
}
