# Padlock for Mac Implementation Plan

**Goal:** Publish a complete native port and universal Mac release.

**Architecture:** AppKit application and menu, SwiftUI settings, a Core Graphics
event tap, validated UserDefaults settings, and dependency-free build scripts.

**Tech stack:** Swift 5.9+, macOS 13+, AppKit, SwiftUI, Core Graphics, Carbon,
ServiceManagement, Swift Package Manager, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-09-padlock-mac-design.md`

## Global constraints

- Follow the user's explicit authorization to complete and publish inline.
- Do not launch the app or run tests; builds and package inspection only.
- Build arm64 and x86_64 for macOS 13 or later.
- Keep the original BSD attribution in source and release bundles.
- Do not persist lock state or request system permissions while building.

## Tasks

- [x] Implement `Models.swift`, `KeyboardLayout.swift`, and `SettingsStore.swift`:
  state and sequence types, layout labels, bounded validation, atomic settings.
- [x] Implement `InputBlocker.swift`: callback, matcher, modes, mouse filtering,
  emergency unlock, key-release bookkeeping, idle detection, and fail-open.
- [x] Implement `AppModel.swift`: permission lifecycle, sleep/wake handling,
  settings edits, login registration, and published state.
- [x] Implement `SettingsView.swift`, `SequenceEditor.swift`,
  `StatusOverlay.swift`, and `PadlockApp.swift`: all original settings, recorders,
  menu actions, setup guidance, display status, and About attribution.
- [x] Add `Resources/Info.plist`, generated app icon, `scripts/build.sh`,
  `scripts/release.sh`, and build/release GitHub Actions. Compile both slices,
  package and ad-hoc sign, and inspect each artifact without launching it.
- [x] Write README, feature parity, architecture, privacy and manual testing
  docs. Preserve upstream license; publish public source and release downloads.
- [x] Confirm remote visibility, commit and tag, asset names and checksums.

Verification records belong in `docs/BUILD-VERIFICATION.md`; runtime checks
remain unchecked in `docs/MANUAL-TESTING.md` for the user's next session.
