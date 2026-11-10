import XCTest
import Foundation
import CoreGraphics
@testable import Padlock

final class ConfigurationTests: XCTestCase {
    private var settings: AppSettings { .defaults }
    private func stroke(_ code: UInt16, _ flags: CGEventFlags = []) -> KeyStroke {
        KeyStroke(keyCode: code, modifiers: flags.rawValue)
    }

    func testFactoryDefaultsAreValidAndAutolockIsOff() {
        XCTAssertNil(settings.validationError)
        XCTAssertEqual(settings.autoLockMinutes, 0)
        XCTAssertEqual(settings.statusVisibility, .always)
        XCTAssertEqual(settings.unlockSequence.count, 4)
        XCTAssertEqual(settings.restrictSequence.first?.modifiers, CGEventFlags.maskAlternate.rawValue)
        XCTAssertEqual(settings.lockSequence.first?.modifiers, CGEventFlags.maskAlternate.rawValue)
    }

    func testEverySequenceMustBeNonempty() {
        for kind in SequenceKind.allCases {
            var candidate = settings
            candidate[kind] = []
            XCTAssertNotNil(candidate.validationError, kind.rawValue)
        }
    }

    func testEverySequenceAcceptsOneAndTenKeysButRejectsEleven() {
        for kind in SequenceKind.allCases {
            for count in [1, 10, 11] {
                var candidate = settings
                candidate[kind] = Array(repeating: stroke(122), count: count)
                XCTAssertEqual(candidate.validationError == nil, count <= 10, "\(kind): \(count)")
            }
        }
    }

    func testDuplicateActionsAreRejectedForEveryPair() {
        for first in SequenceKind.allCases {
            for second in SequenceKind.allCases where first != second {
                var candidate = settings
                candidate[first] = candidate[second]
                XCTAssertNotNil(candidate.validationError)
            }
        }
    }

    func testPrefixAmbiguityIsRejectedInBothOrders() {
        for first in SequenceKind.allCases {
            for second in SequenceKind.allCases where first != second {
                var candidate = settings
                candidate[first] = [stroke(122)]
                candidate[second] = [stroke(122), stroke(120)]
                XCTAssertNotNil(candidate.validationError)
            }
        }
    }

    func testSharedPartialPrefixAndSuffixAreValid() {
        var candidate = settings
        candidate.unlockSequence = [stroke(122), stroke(120)]
        candidate.restrictSequence = [stroke(122), stroke(99)]
        candidate.lockSequence = [stroke(120), stroke(122)]
        XCTAssertNil(candidate.validationError)
    }

    func testSamePhysicalKeyWithDifferentModifiersIsUnambiguous() {
        var candidate = settings
        candidate.unlockSequence = [stroke(122)]
        candidate.restrictSequence = [stroke(122, .maskAlternate)]
        candidate.lockSequence = [stroke(122, .maskCommand)]
        XCTAssertNil(candidate.validationError)
    }

    func testEmergencyShortcutCannotBeEmbeddedInAnySequence() {
        for kind in SequenceKind.allCases {
            var candidate = settings
            candidate[kind] = [stroke(122), .emergency]
            XCTAssertNotNil(candidate.validationError)
        }
    }

    func testModifierOnlyAndUnknownKeyCodesAreRejected() {
        for code in KeyboardLayout.modifierCodes.union([UInt16.max, 127]) {
            var candidate = settings
            candidate.unlockSequence = [stroke(code)]
            XCTAssertNotNil(candidate.validationError, String(code))
        }
    }

    func testAutolockInclusiveBounds() {
        for minutes in [-1, 0, 1, 1440, 1441, Int.max] {
            var candidate = settings
            candidate.autoLockMinutes = minutes
            XCTAssertEqual(candidate.validationError == nil, (0...1440).contains(minutes))
        }
    }

    func testUnknownSchemaIsRejected() {
        var candidate = settings
        candidate.schemaVersion = 2
        XCTAssertNotNil(candidate.validationError)
    }

    func testModifierNormalizationIgnoresCapsLockAndFn() {
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand,
                                   .maskAlphaShift, .maskSecondaryFn, .maskNumericPad]
        XCTAssertEqual(stroke(0, flags).modifiers, KeyStroke.modifierMask)
        XCTAssertEqual(stroke(0, [.maskAlphaShift, .maskSecondaryFn]).modifiers, 0)
    }

    func testMalformedDecodedModifierBitsAreRejected() throws {
        let data = Data(#"{"keyCode":0,"modifiers":1}"#.utf8)
        let decoded = try JSONDecoder().decode(KeyStroke.self, from: data)
        XCTAssertFalse(decoded.isValid)
        var candidate = settings
        candidate.unlockSequence = [decoded]
        XCTAssertNotNil(candidate.validationError)
    }

    func testConfiguredStrokesRoundTripIncludingNavigationAndAllModifiers() throws {
        var candidate = settings
        candidate.unlockSequence = [stroke(36), stroke(48), stroke(53), stroke(123, .maskShift)]
        candidate.lockSequence = [stroke(122, [.maskControl, .maskAlternate, .maskShift, .maskCommand])]
        candidate.autoLockMinutes = 1440
        candidate.statusVisibility = .whenBlocking
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(candidate))
        XCTAssertEqual(decoded, candidate)
        XCTAssertNil(decoded.validationError)
    }

    func testEditingOneSequenceKeepsOthersUnchanged() {
        for kind in SequenceKind.allCases {
            var candidate = settings
            candidate[kind] = [stroke(122)]
            for other in SequenceKind.allCases where other != kind {
                XCTAssertEqual(candidate[other], settings[other])
            }
        }
    }

    func testCGEventPreservesPhysicalKeyAndSequenceModifiers() throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 37, keyDown: true))
        event.flags = [.maskAlternate, .maskShift, .maskAlphaShift]
        XCTAssertEqual(KeyStroke(event: event), stroke(37, [.maskAlternate, .maskShift]))
    }

    func testRestrictedAllowlistIncludesAllANSILettersDigitsAndKeypadDigits() {
        let letters: [UInt16] = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,31,32,34,35,37,38,40,45,46]
        let digits: [UInt16] = [18,19,20,21,22,23,25,26,28,29,82,83,84,85,86,87,88,89,91,92]
        for code in letters + digits { XCTAssertTrue(KeyboardLayout.isAlphanumeric(code), String(code)) }
    }

    func testRestrictedAllowlistExcludesEditingFunctionAndPunctuationKeys() {
        for code: UInt16 in [24,27,30,33,36,39,41,42,43,44,47,48,50,51,53,65,67,69,71,75,76,78,81,96,122] {
            XCTAssertFalse(KeyboardLayout.isAlphanumeric(code), String(code))
        }
        XCTAssertEqual(KeyboardLayout.navigationCodes, [49,115,116,119,121,123,124,125,126])
    }

    func testAllSupportedCodesHaveLabels() {
        for code in KeyboardLayout.supportedCodes {
            XCTAssertFalse(KeyboardLayout.name(for: code).isEmpty)
        }
    }

    func testModifierAndEmergencyLabelsAreUnambiguous() {
        XCTAssertEqual(KeyStroke.emergency.title, "⌃⌥⌘Esc")
        XCTAssertTrue(stroke(122, [.maskControl, .maskAlternate, .maskShift, .maskCommand]).title
            .hasPrefix("⌃⌥⇧⌘"))
    }
}

final class PersistenceTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var store: SettingsStore!
    private let key = "Padlock.settings.v1"

    override func setUpWithError() throws {
        suite = "io.github.pdgamersg.padlock.validation.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testFirstRunLoadsValidDefaultsWithoutNotice() {
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, .defaults)
        XCTAssertNil(loaded.notice)
    }

    func testSavedSettingsSurviveNewStoreInstance() throws {
        var expected = AppSettings.defaults
        expected.autoLockMinutes = 7
        expected.statusVisibility = .never
        expected.unlockSequence = [KeyStroke(keyCode: 122), KeyStroke(keyCode: 120)]
        try store.save(expected)
        let restored = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(restored.settings, expected)
        XCTAssertNil(restored.notice)
    }

    func testInvalidSaveDoesNotOverwriteLastValidSettings() throws {
        var valid = AppSettings.defaults
        valid.autoLockMinutes = 9
        try store.save(valid)
        let original = defaults.data(forKey: key)
        var invalid = valid
        invalid.unlockSequence = []
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(defaults.data(forKey: key), original)
        XCTAssertEqual(store.load().settings, valid)
    }

    func testMalformedJSONFallsBackWithVisibleNotice() {
        defaults.set(Data("{broken".utf8), forKey: key)
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, .defaults)
        XCTAssertNotNil(loaded.notice)
    }

    func testInvalidDecodedSettingsFallBackWithVisibleNotice() throws {
        var invalid = AppSettings.defaults
        invalid.unlockSequence = []
        defaults.set(try JSONEncoder().encode(invalid), forKey: key)
        XCTAssertEqual(store.load().settings, .defaults)
        XCTAssertNotNil(store.load().notice)
    }

    func testUnknownSchemaFallsBackWithVisibleNotice() throws {
        var invalid = AppSettings.defaults
        invalid.schemaVersion = 99
        defaults.set(try JSONEncoder().encode(invalid), forKey: key)
        XCTAssertEqual(store.load().settings, .defaults)
        XCTAssertNotNil(store.load().notice)
    }

    func testEveryStatusVisibilityPersists() throws {
        for visibility in StatusVisibility.allCases {
            var candidate = AppSettings.defaults
            candidate.statusVisibility = visibility
            try store.save(candidate)
            XCTAssertEqual(store.load().settings.statusVisibility, visibility)
        }
    }

    func testStoredDataDoesNotContainCurrentModeOrHistory() throws {
        try store.save(.defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: key))) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "unlockSequence", "restrictSequence",
                                         "lockSequence", "autoLockMinutes", "statusVisibility"])
    }
}
