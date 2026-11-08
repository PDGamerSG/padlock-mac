# Padlock for Mac

Port the behavior of takuyakanbr/padlock at commit
`01a7590b9558977efc54913d2396d30cf1df8020` to a native macOS menu bar utility.
The user authorized the complete implementation, a public repository, and a
downloadable release, and explicitly deferred testing. Proceed inline without
additional approval gates or running the application or a test suite.

## Acceptance

- macOS 13 or later; Apple silicon and Intel in one application.
- Default permits input. Restricted permits letters, digits, Shift, Space,
  Page Up/Down, Home/End, and arrows, with no Command/Control/Option shortcuts.
  Both Restricted and Locked block mouse movement, buttons, dragging, and scroll.
  Locked also blocks keyboard input, subject to macOS protected system controls.
- Defaults: Option+R restricts, Option+L locks, and `asdf` unlocks. Default can
  enter either mode; Restricted can enter Locked; unlock returns to Default.
- Record 1–10 physical keystrokes with modifiers for each action, persist
  settings, reject ambiguous prefixes and invalid/empty unlock sequences.
- Idle lock in whole minutes; zero disables it. Actual pointer movement counts
  as activity, and a timer triggers locking without waiting for another input.
- Status box has Always show, Hide when unlocked, and Always hide choices.
  It sits at the lower right of each display and never steals input.
- Menu bar icon reflects state. Settings and quit are available in Default;
  editing pauses automatic locking and sequence actions.
- Native permission setup for Accessibility and Input Monitoring, optional
  launch at login, and an immutable Control+Option+Command+Escape escape hatch.
- No network activity in the app, telemetry, captured input logs, or dependencies.
- Loss of tap, permission, secure input, sleep, or session deactivation returns
  to Default. A subsequent launch always starts in Default.
- BSD-3-Clause attribution in source, About, and binary distributions.
- Build scripts produce an app, ZIP, DMG, and SHA-256 checksums. Public GitHub
  source and release include honest build-only verification notes.

## Design

Swift Package Manager provides the development project. AppKit owns the
application, menu, settings window, and passive status panels. SwiftUI renders
native settings controls. A Core Graphics event tap on the main run loop owns
input filtering and sequence state. UI notifications are deferred out of the
tap callback to keep it short. Keyboard layout translation supplies readable
sequence labels; stored strokes identify physical keys.

Settings use validated, versioned Codable data in UserDefaults. Configuration
does not persist the current blocking mode. A one-second coordinator checks
permissions, secure input, event tap health, and idle time. Synthesized release
events prevent previously delivered keys and buttons remaining held when a
mode changes, and suppressed key-up tracking prevents partial keystroke leaks.

The visual language is a compact native utility: system type, system adaptive
backgrounds, blue interactive controls, amber Restricted and red Locked state.
The original five settings remain together, with separate permission and login
controls. No website, account, daemon, or extra provider is required.

## Platform limits and delivery

This is an input utility, not a macOS authentication or screen lock replacement.
Power/Touch ID, some OS-reserved shortcuts, loginwindow, protected input,
hardware gestures, and privileged input paths are outside a user event tap's
guarantees. Fail open when protection cannot be maintained. The escape hatch
deliberately differs from upstream to make recovery possible.

No Developer ID identity is present on this build machine. The initial public
release is ad-hoc signed and not notarized; include Open Anyway instructions.
Compile and inspect bundles, signatures, architectures, disk-image integrity,
and release assets. Do not launch the app, request system permissions, simulate
input, or execute tests in this session. Include a manual checklist for the
user's later testing and clearly mark it unexecuted.
