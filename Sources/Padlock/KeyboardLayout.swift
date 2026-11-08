import Carbon

enum KeyboardLayout {
    private static let special: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        64: "F17", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +",
        71: "Clear", 75: "Keypad /", 76: "Keypad Enter", 78: "Keypad −",
        79: "F18", 80: "F19", 81: "Keypad =", 82: "Keypad 0",
        83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4",
        87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 90: "F20",
        91: "Keypad 8", 92: "Keypad 9", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete",
        118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        93: "¥", 94: "_", 95: "Keypad ,", 102: "Eisu", 104: "Kana"
    ]

    private static let fallback: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
        7: "X", 8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W",
        14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "−",
        28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
        35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`"
    ]

    static let supportedCodes = Set(special.keys).union(fallback.keys)
    static let modifierCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    static let navigationCodes: Set<UInt16> = [49, 115, 116, 119, 121, 123, 124, 125, 126]

    static func name(for code: UInt16) -> String {
        special[code] ?? translated(code)?.uppercased() ?? fallback[code] ?? "Key \(code)"
    }

    static func code(for character: String) -> UInt16? {
        fallback.keys.sorted().first { translated($0)?.lowercased() == character.lowercased() }
    }

    static func isAlphanumeric(_ code: UInt16) -> Bool {
        // Physical ANSI letter/number keys, plus numeric keypad digits. Do not
        // translate layouts or allocate strings inside the event tap callback.
        alphanumericCodes.contains(code)
    }

    private static let alphanumericCodes: Set<UInt16> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17,
        18, 19, 20, 21, 22, 23, 25, 26, 28, 29, 31, 32, 34, 35, 37, 38,
        40, 45, 46, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92
    ]

    private static func translated(_ code: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKey: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), 0,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                    &deadKey, characters.count, &length, &characters)
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
        return text.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
            ? text : nil
    }
}
