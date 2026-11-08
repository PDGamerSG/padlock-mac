# Architecture

## Source map

- `PadlockApp.swift`: NSApplication entry, single-instance check, menu bar,
  application menu, settings window lifecycle, About, and help.
- `AppModel.swift`: observable presentation state, privacy permission checks,
  settings application, login registration, and one-second lifecycle timer.
- `InputBlocker.swift`: event tap and blocking state, sequence matching, idle
  threshold, emergency return to Default, and key/button release bookkeeping.
- `Models.swift`: mode, sequence, and configuration types and validation.
- `KeyboardLayout.swift`: physical key codes and human-readable layout labels.
- `SettingsStore.swift`: versioned Codable preferences in UserDefaults.
- `SettingsView.swift`: original five settings, permission setup, and Mac options.
- `SequenceEditor.swift`: isolated draft recording and local event monitor.
- `StatusOverlay.swift`: passive NSPanel status indicators on every display.
- `ViewState.swift`: alias for the SwiftUI State property wrapper, avoiding the
  macOS 27 SDK's same-named macro when using standalone Command Line Tools.

## Input path

One `CGEventTap` at the head of the user-session event stream filters delivered
input. It is installed with filtering enabled, never listen-only. The tap's
run-loop source lives in main-run-loop common modes, so state, menus, and settings
have a single owner. Callbacks do no filesystem IO or UI layout. Published mode
updates are enqueued outside the callback.

Keyboard strokes contain a physical virtual key code and normalized
Control/Option/Shift/Command flags. Non-repeating key-down events feed a bounded
ten-stroke suffix matcher. It handles overlapping partial matches without
dropping a valid beginning. All configured action sequences must be nonempty,
valid, distinct, and not prefixes of each other. The fixed emergency shortcut
is checked before configurable matching and cannot be assigned to a sequence.

The final key-down triggering a mode action is consumed, along with its key-up.
In Locked mode all ordinary keys are discarded. In Restricted mode only the
allowlist without Command/Control/Option is forwarded. Allowed earlier strokes
of an unlock sequence can be forwarded in Restricted mode, matching upstream's
behavior; the app does not buffer or replay ordinary text.

The tap records which key presses and pointer-button presses reached client
applications. Entering a blocking mode sends marked release events for those
presses. Discarded key-down events have their future autorepeats/key-up discarded
until the physical key is released. Modifier releases remain available to clear
state. Marked internally generated releases pass through this tap.

Pointer movement, dragging, scroll, tablet, and other delivered session events
are dropped in either blocking mode. The visible pointer is pinned to its
activation position with `CGWarpMouseCursorPosition`, which generates no new
events, so movement already applied by WindowServer does not accumulate. No
root-only HID tap or persistent cursor/mouse disassociation is used.
Hardware and protected OS input that the
session tap never receives cannot be promised to be suppressed.

## Lifecycle and idle lock

Blocking mode exists only in memory; startup is always Default. The coordinator
checks Accessibility, Input Monitoring, Secure Keyboard Entry, and tap health.
It returns to Default when the tap is interrupted, either permission disappears,
or protected input takes over. Sleep/display-sleep and user-session deactivation
remove the tap; wake resumes in Default with a fresh idle interval.

The one-second idle check uses the minimum of the app's activity interval and
the system's time since any input, avoiding locking while protected input is
active. All observed default-mode events refresh activity. Settings and key
recording pause action sequences and idle locking. Closing Settings starts a
fresh inactivity period.

## Persistence and packaging

Validated `AppSettings` data is encoded as one JSON value in UserDefaults. Invalid
or unsupported saved settings fall back to defaults with a visible notice.
No input history is persisted. Login registration uses `SMAppService.mainApp`
and is governed by macOS Login Items separately from app preferences.

SwiftPM supplies source editing and compilation. `scripts/build.sh` compiles
macOS 13-targeted arm64/x86_64 slices and combines them with `lipo`, copies the
Info.plist, icon and license/help, and signs the finished bundle. `release.sh`
adds ZIP, compressed read-only DMG, and SHA-256 checksums. App Sandbox is not
enabled because this utility needs global filtering. No helper or daemon runs.
