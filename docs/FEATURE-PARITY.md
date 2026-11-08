# Feature parity

Reference: takuyakanbr/padlock commit
`01a7590b9558977efc54913d2396d30cf1df8020` (Windows version 1.12).

| Original feature | Mac implementation |
| --- | --- |
| Default, Restricted, Locked | Same mode names and transition rules |
| Alt+R restricts | Option+R by default |
| Alt+L locks | Option+L by default |
| `asdf` unlocks | `asdf` by default, detected globally |
| Editable modifier-aware sequences, up to 10 strokes | Native recorder, with Control, Option, Shift, and Command |
| Restricted allows alphanumeric keys, Shift, Space, navigation | Same category allowlist, plus numeric keypad digits |
| Mouse blocked in Restricted and Locked | Movement, click, drag, scroll, and other delivered pointer events are discarded |
| Idle lock, minutes, zero disables | Persisted 0–1,440 minute setting; timer observes actual inactivity |
| Status box at bottom right | Passive panel at bottom right of every display |
| Always show / hide when unlocked / always hide | Same three choices, with hide-when-unlocked behavior corrected |
| Tray icon follows mode | Native macOS menu bar icon and accessible state label |
| Tray menu opens Settings and Exit | Click/right-click menu offers Settings and Quit, plus direct mode actions and Help |
| Double-click tray opens Settings | Double-click action handled where delivered by macOS; Settings menu remains the standard Mac entry point |
| Per-user settings file | Validated, versioned UserDefaults preferences |
| No elevated Windows hooks | macOS Accessibility and Input Monitoring permission setup |

## Improvements

- Fixed immutable emergency unlock: Control+Option+Command+Escape.
- No blocking while a sequence is being edited; Save and Cancel are explicit.
- Reject empty, duplicate, reserved, or ambiguous prefix sequences before saving.
- Unlock state is never persisted and blocking fails open if filtering is lost.
- Release previously forwarded keys/buttons when blocking starts, and consume
  matching releases for discarded key presses.
- Idle lock is a real timer and mouse movement counts as activity. Upstream
  checks inactivity on the next input and omits ordinary mouse movement.
- Correct upstream's hide-when-unlocked switch fallthrough, which also hides
  the status box in blocking modes.
- Multi-display status, light/dark adaptation, VoiceOver labels, optional native
  launch at login, and offline bundled help/license.
- Universal Mac package, build scripts, automated build and release workflows.

## macOS limits

The Windows hooks and administrator behavior cannot be copied literally onto
macOS. Event filtering depends on a user-session Core Graphics tap and system
privacy permissions. Protected input, loginwindow, power/Touch ID, OS-reserved
shortcuts, privileged software, and some hardware gestures remain controlled by
macOS. Secure Keyboard Entry pauses Padlock. This utility does not authenticate
users or replace macOS Lock Screen. The initial build is ad-hoc signed and not
notarized. Runtime behavior remains to be tested by the user.
