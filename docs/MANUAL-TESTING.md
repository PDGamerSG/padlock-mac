# Manual testing checklist

The initial build session deferred testing. Runtime verification was subsequently
started on 2026-11-10–11; see the [dated test report](TEST-REPORT-2026-11-11.md)
for the executed automated/live checks, results, and remaining gaps. This manual
checklist remains unchecked so unexecuted physical-device and system-lifecycle
checks are not confused with synthetic-event coverage. Record macOS version,
hardware, keyboard layout, and app version when reporting an issue.

## Install and permissions

- [ ] Install the release app into Applications and open it through Finder.
- [ ] Confirm menu bar presence, first-run settings, default sequences, and status.
- [ ] Without permissions, confirm mode activation is unavailable and input works.
- [ ] Enable Accessibility and Input Monitoring using the two Allow buttons.
- [ ] Quit/reopen if requested by macOS; confirm Input filtering ready appears.
- [ ] Verify normal typing, shortcuts, clicks, drag, scroll, and pointer motion.

## Modes and recovery

- [ ] Close Settings. In an empty text document, press Option+R.
- [ ] In Restricted, verify letters, digits, keypad digits, Shift, Space, arrows,
  Home, End, Page Up, and Page Down. Verify punctuation, Return, Delete, Tab,
  Command/Control/Option combinations, movement, clicks, dragging, and scroll block.
- [ ] Type `asdf` to return to Default. Earlier allowed unlock characters can
  appear in the document in Restricted mode, as in the original application.
- [ ] Press Option+L. Verify ordinary keyboard and pointer input block.
- [ ] Type `asdf` with no modifiers to unlock; repeat after mistyping a prefix.
- [ ] Escalate from Restricted to Locked with Option+L.
- [ ] In each blocking mode, verify Control+Option+Command+Escape recovers.
- [ ] Hold keys/modifiers/buttons through a mode transition, release, and verify
  none remain stuck or produce stray releases or autorepeat after unlocking.
- [ ] Confirm Settings and Quit are unavailable until returning to Default.

## Preferences and recording

- [ ] Record 1-key and 10-key sequences, modifier combinations, repeated keys,
  Tab, Return, Escape, function keys, and supported navigation keys.
- [ ] Save/Cancel/Clear work; cancel leaves the old sequence unchanged.
- [ ] Empty, duplicate, prefix-conflicting, and emergency sequences cannot save.
- [ ] Keyboard activity while Settings is open does not activate blocking.
- [ ] Close/reopen Settings, then quit/relaunch; verify preferences persist.
- [ ] Review labels and behavior after switching keyboard layouts.
- [ ] Restore Defaults restores all five original settings without changing
  permission or launch-at-login settings.

## Idle and status

- [ ] Set autolock to 1 minute; close Settings; verify locking around the threshold.
- [ ] Mouse movement, scrolling, and typing reset the inactivity timer.
- [ ] Idle locking stays paused while Settings is open.
- [ ] Set 0; verify autolock stays disabled. Reject invalid/negative/large values.
- [ ] Verify all three status visibility settings in all modes.
- [ ] Connect/disconnect a display; change Dock position, Spaces, and full screen.
- [ ] Check light/dark appearance, keyboard navigation, and VoiceOver labels.

## macOS lifecycle

- [ ] Remove permissions while running; input resumes and the status updates.
- [ ] With Terminal Secure Keyboard Entry enabled, Padlock pauses; after disabling
  it, filtering becomes available and can be activated again.
- [ ] Sleep/wake and switch user sessions; Padlock resumes in Default.
- [ ] Enable/disable launch at login and verify registration in Login Items.
- [ ] Log out/in with login enabled; Padlock starts in Default.
- [ ] Open Padlock twice; only one instance remains.
- [ ] Quit; no overlay, menu item, or filtering remains.
- [ ] Exercise protected OS controls separately; do not expect Padlock to replace
  system authentication or block power/Touch ID and every hardware gesture.

## Architectures

- [ ] Apple silicon: complete the checklist using the native arm64 slice.
- [ ] Intel: complete the checklist on an Intel Mac using the x86_64 slice.
- [ ] Verify on macOS 13 and a current macOS version where hardware is available.
