# Verification tools

These tests were added to verify the initial release. They do not change the
application's filtering logic or add a test mode to the shipped app.

## Configuration and persistence

```bash
./scripts/test.sh
```

Compiles the unchanged configuration, keyboard-layout, and persistence sources
and runs 28 test methods with 275 assertions. The runner uses an isolated
UserDefaults suite for each persistence case. It does not install an event tap
or send input. It works with standalone Apple Command Line Tools.

With full Xcode selected, the same tests are available through:

```bash
swift test --build-system native
```

Standalone Command Line Tools may lack XCTest. `scripts/test.sh` uses the
assertion adapter in `StandaloneRunner.swift` to run the same test bodies without
installing dependencies or rewriting the application's behavior.

## Interactive verification

Run these only in an unlocked, awake desktop session after explicitly deciding
to exercise global input filtering. Keep other keyboard/mouse activity out of
the test window. Accessibility and Input Monitoring must be granted to Padlock,
and Accessibility/event posting must be available to the test driver.

```bash
xcrun swiftc -swift-version 5 -parse-as-library Tests/LiveInputProbe.swift \
  -o build/validation/live-input-probe
open dist/Padlock.app
# Open Padlock Settings before starting each probe.
build/validation/live-input-probe
build/validation/live-input-probe --held-stress
```

The probe sends marked synthetic input through the real macOS event stream to
a temporary AppKit window. It checks both Padlock's accessible mode indicator
and what input actually arrives at that window. A separate timed watchdog can
terminate only the tested Padlock PID if the probe stalls. Normal cleanup sends
the emergency unlock when necessary. Other users' input is not recorded.

The standard probe expects the default Option+R/Option+L action shortcuts and
reads the current unlock sequence. Restore `asdf` for the standard full suite,
whose wrong-modifier and partial-match cases are defined for those letters.
The stress probe tests 25 held-key transition cycles. Timing and focus failures
must be investigated rather than counted as product failures without evidence.

```bash
python3 Tests/UIValidation.py
```

The UI driver uses macOS Accessibility via System Events to exercise the native
recorder, validation, Save/Cancel/Clear, status choices, and idle duration field.
It backs up settings in memory and restores changes while the session remains
available. Keep a `defaults export` backup as well. It stops if the desktop locks;
quit the test-launched app and restore the backup if UI cleanup cannot run.

Never run the interactive tools in unattended CI. They affect the current user
session and cannot substitute for physical keyboard, trackpad, multi-monitor,
older macOS, or real Intel hardware checks. See the dated test report in `docs`.
