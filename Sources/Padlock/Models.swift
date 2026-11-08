import AppKit
import CoreGraphics

enum InputMode: String, CaseIterable {
    case unlocked, restricted, locked

    var title: String {
        switch self {
        case .unlocked: return "Default"
        case .restricted: return "Restricted"
        case .locked: return "Locked"
        }
    }

    var symbol: String {
        switch self {
        case .unlocked: return "lock.open"
        case .restricted: return "lock.lefthalf.filled"
        case .locked: return "lock.fill"
        }
    }

    var color: NSColor {
        switch self {
        case .unlocked: return .secondaryLabelColor
        case .restricted: return .systemOrange
        case .locked: return .systemRed
        }
    }
}

enum SequenceKind: String, Codable, CaseIterable, Identifiable {
    case unlock, restrict, lock
    var id: String { rawValue }
    var title: String { rawValue.capitalized + " sequence" }
}

enum StatusVisibility: Int, Codable, CaseIterable, Identifiable {
    case always, whenBlocking, never
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .always: return "Always show"
        case .whenBlocking: return "Hide when unlocked"
        case .never: return "Always hide"
        }
    }
}

struct KeyStroke: Codable, Equatable, Hashable {
    static let modifierMask = CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskShift.rawValue
        | CGEventFlags.maskCommand.rawValue
    static let emergency = KeyStroke(keyCode: 53, modifiers:
        CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskCommand.rawValue)

    let keyCode: UInt16
    let modifiers: UInt64

    init(keyCode: UInt16, modifiers: UInt64 = 0) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
    }

    init(event: CGEvent) {
        self.init(keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                  modifiers: event.flags.rawValue)
    }

    init(event: NSEvent) {
        self.init(keyCode: event.keyCode, modifiers: UInt64(event.modifierFlags.rawValue))
    }

    var isValid: Bool {
        KeyboardLayout.supportedCodes.contains(keyCode)
            && modifiers & ~Self.modifierMask == 0 && self != Self.emergency
    }

    var title: String {
        let flags = CGEventFlags(rawValue: modifiers)
        var result = ""
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskShift) { result += "⇧" }
        if flags.contains(.maskCommand) { result += "⌘" }
        return result + KeyboardLayout.name(for: keyCode)
    }
}

struct AppSettings: Codable, Equatable {
    var schemaVersion = 1
    var unlockSequence: [KeyStroke]
    var restrictSequence: [KeyStroke]
    var lockSequence: [KeyStroke]
    var autoLockMinutes = 0
    var statusVisibility = StatusVisibility.always

    static var defaults: AppSettings {
        AppSettings(
            unlockSequence: zip(["a", "s", "d", "f"], [UInt16(0), 1, 2, 3]).map {
                KeyStroke(keyCode: KeyboardLayout.code(for: $0.0) ?? $0.1)
            },
            restrictSequence: [KeyStroke(keyCode: KeyboardLayout.code(for: "r") ?? 15,
                                        modifiers: CGEventFlags.maskAlternate.rawValue)],
            lockSequence: [KeyStroke(keyCode: KeyboardLayout.code(for: "l") ?? 37,
                                    modifiers: CGEventFlags.maskAlternate.rawValue)]
        )
    }

    subscript(kind: SequenceKind) -> [KeyStroke] {
        get {
            switch kind {
            case .unlock: return unlockSequence
            case .restrict: return restrictSequence
            case .lock: return lockSequence
            }
        }
        set {
            switch kind {
            case .unlock: unlockSequence = newValue
            case .restrict: restrictSequence = newValue
            case .lock: lockSequence = newValue
            }
        }
    }

    var validationError: String? {
        guard schemaVersion == 1 else { return "This settings version is not supported." }
        guard (0...1440).contains(autoLockMinutes) else {
            return "Autolock must be between 0 and 1,440 minutes."
        }
        for kind in SequenceKind.allCases {
            guard (1...10).contains(self[kind].count), self[kind].allSatisfy(\.isValid) else {
                return "Each sequence needs 1–10 keys. The emergency shortcut is reserved."
            }
        }
        let kinds = SequenceKind.allCases
        for i in kinds.indices {
            for j in kinds.indices where j > i {
                let a = self[kinds[i]], b = self[kinds[j]]
                if a.starts(with: b) || b.starts(with: a) {
                    return "Sequences must be different and cannot start with another sequence."
                }
            }
        }
        return nil
    }

    func title(for kind: SequenceKind) -> String {
        self[kind].map(\.title).joined(separator: "  ")
    }
}
