# Padlock 1.0.0 runtime test report

**Result: core keyboard/pointer blocking and recovery passed on this Mac.
Full release sign-off remains incomplete.** The desktop locked before the live
idle-duration and idle-timer checks could finish. An early held-key assertion
also failed intermittently; a detailed rerun and 25 subsequent transition cycles
passed, so that observation is retained as a timing/focus concern rather than
silently discarded.

Test dates: 2026-11-10–11. Host: Apple silicon, macOS 27.0.1 (26A434), Swift 6.4
Command Line Tools. Tested bundle: the original `dist/Padlock.app`, version 1.0.0,
with application sources matching release commit
`a2d44ae6fae91e9bd53d9cde1e75822fdd89fad2`. **No product source or release binary
was changed during this verification.** Test tools and a SwiftPM test target
were added separately.

## Passed

- **28 configuration/persistence tests, 275 assertions, zero failures** on arm64.
  The same tests also passed as x86_64 under Rosetta, with **275 assertions and
  zero failures**. Tests cover sequence limits, duplicates/prefix ambiguity,
  modifiers, reserved keys, layout labels, allowlists, all visibility values,
  setting bounds, JSON round-trips, invalid-save protection, and corrupt or
  unsupported preferences. Persistence cases use isolated temporary domains.
- **30 live input checks passed** in the detailed run. The packaged app reported
  both required permissions granted. Synthetic marked Quartz events passed
  through its real session event tap to a separate temporary AppKit window.
  Assertions checked both the accessible mode and the events the target received.
- **25 repeated held-key transition cycles passed** in the detailed stress run,
  plus the two startup/settings prerequisites. Every cycle verified lock,
  unlock, held-key autorepeat suppression, and successful input after release.
- **14 native UI checks passed:** empty Save disabled; distinct keys recorded;
  Cancel preserved the configured sequence; duplicates rejected without saving;
  Clear reset the draft; emergency sequence rejected; ten keys accepted;
  eleventh key rejected; Tab/Return/Escape recorded; Save persisted a custom
  sequence; Always hide/Always show toggled the visible panel; Hide when unlocked
  hid the panel in Default mode.
- The application launched, its native Settings window and menu bar were
  accessible, and permission readiness appeared. The real desktop becoming
  inactive caused the app to report that filtering was paused.
- The published bundle's strict code-signature inspection passed. It contains
  both arm64 and x86_64 slices. The existing GitHub build completed successfully:
  [build run](https://github.com/PDGamerSG/padlock-mac/actions/runs/42526139529).

### Live input behaviors exercised

Default-mode key, pointer-button, and scroll delivery; settings-paused sequences;
autorepeat not triggering actions; Option+R and Option+L mode entry; full
Restricted key allowlist; Shift combinations; rejected Control/Option/Command
shortcuts; blocked punctuation/editing/function keys; discarded pointer input
and fixed cursor position; mistyped and wrong-modifier unlock rejection;
configured unlock; overlapping partial sequences; Restricted-to-Locked
escalation; immutable emergency unlock; release of already-forwarded held keys;
suppressed held-key repeats; recovery after release; Secure Keyboard Entry
returning to Default; and filtering becoming available after Secure Keyboard
Entry ends.

## Failures, blockers, and investigation

1. The project originally had no tests. `swift test` first reported no tests;
   after adding a test target, this Command Line Tools installation reported
   `no such module 'XCTest'`. A dependency-free assertion adapter now runs the
   same test bodies against the unchanged product sources. Full Xcode can run
   the regular XCTest target. These were test-infrastructure issues.
2. During the first session, Google Chrome held Secure Keyboard Entry. Padlock
   remained in Default as designed. Blocking verification resumed after that
   external condition ended.
3. A held-key recovery assertion initially observed Locked instead of Default;
   a later stress attempt also observed one failure. The first detailed rerun
   passed all 30 cases, and 25 subsequent detailed cycles passed. Some earlier
   attempts also incorrectly assumed `asdf` after the UI tests had changed the
   configured unlock sequence. The driver now reads the current sequence and
   records intermediate mode/delivery observations. There is no confirmed
   product fix or conclusive root cause for the intermittent observation.
4. Native UI verification reached the idle-duration field but could not prove
   a saved value. The session then reported
   `CGSSessionScreenIsLocked=1` and Padlock reported
   `Paused while the session is inactive`; its Settings window was unavailable
   for further UI actions. Idle-field editing is **inconclusive**, not a pass.
   No assertion about a working inactivity timer is made.

## Still unverified

- Live editing/validation of the idle-duration text field and actual one-minute
  inactivity locking, including movement resetting the timer.
- Hide-when-unlocked appearance while actually blocked; full-screen/Spaces and
  additional physical displays.
- Permission revocation during a lock, actual sleep/wake and user switching,
  login registration and a subsequent login, and repeated-instance launching.
- Direct menu-triggered activation, physical keyboard/trackpad behavior,
  protected hardware/system controls, VoiceOver, and appearance checks.
- Real Intel hardware and macOS 13–26 runtime behavior. Rosetta execution of the
  configuration tests is useful evidence, not an Intel hardware/old-OS test.
- Fresh-download Gatekeeper/installation behavior on a different Mac. The build
  remains ad-hoc signed and not notarized.

## Reproduce and finish

Run `./scripts/test.sh` for configuration/persistence tests. See
[`Tests/README.md`](../Tests/README.md) for interactive test commands. The live
probes require an unlocked, awake desktop with Secure Keyboard Entry off and
the required permissions available. Their synthetic event source and temporary
target do not capture unmarked personal input. A separate timeout watchdog
terminates only the test's Padlock PID if recovery stalls.

Raw local evidence is retained under ignored `build/validation/`:

- `behavior-tests.log`, `behavior-tests-rosetta.log`
- `live-input-hold-diagnostic.log` (30 checks passed)
- `live-input-stress-diagnostic.log` (25 cycles and two prerequisites passed)
- `live-input.log`, `live-input-stress-current-config.log` (earlier failures)
- `native-ui.log` (14 passes, interrupted idle-field attempt)

The test-launched Padlock instance was quit after the desktop locked. All
original app settings were restored from the pre-test backup and compared:
`asdf` unlock, Option+R restrict, Option+L lock, idle disabled, status always
visible. No watchdog, event probe, or input lock was left running.
