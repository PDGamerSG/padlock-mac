# Padlock for Mac

A native Mac port of [takuyakanbr/padlock](https://github.com/takuyakanbr/padlock),
the small utility that blocks keyboard and mouse input until you type an unlock
sequence. Same three modes, key sequences, idle locking, and corner status box,
with a macOS menu bar app and native settings.

**[Download the latest release](https://github.com/PDGamerSG/padlock-mac/releases/latest)**
· macOS 13 Ventura or later · Apple silicon and Intel · No runtime dependencies

## Install

1. Download `Padlock-1.0.0-universal.dmg` from Releases.
2. Open the disk image and drag **Padlock.app** into **Applications**.
3. Open Padlock. This release is **ad-hoc signed and not notarized**. If macOS
   blocks it, attempt to open it once, then use **System Settings → Privacy &
   Security → Open Anyway** for Padlock. A ZIP download is also available.
4. In Padlock Settings, allow **Accessibility** and **Input Monitoring**. Enable
   Padlock in both privacy lists. Quit and reopen it if macOS asks you to.
5. Close Settings to enable key sequences and autolock. The menu bar icon stays
   available after the window closes.

Padlock does not install a daemon, ask for an account, or require administrator
execution. Use the installed app rather than the executable inside its bundle;
macOS associates permissions and launch at login with the app's identity and path.

## Use

| Action | Default sequence |
| --- | --- |
| Enter Restricted mode | **Option + R** (`⌥R`) |
| Enter Locked mode | **Option + L** (`⌥L`) |
| Return to Default | Type **a s d f**, without modifiers |
| Emergency return to Default | **Control + Option + Command + Escape** (`⌃⌥⌘Esc`) |

Type the sequences anywhere; do not type them into a special unlock field.
You can also select **Restrict Input** or **Lock Input** in the menu bar menu.
The built-in emergency sequence cannot be edited or assigned to another action.

| Mode | Allowed input |
| --- | --- |
| **Default** | All keyboard and pointer input |
| **Restricted** | Letters, digits (including numeric keypad), Shift, Space, Page Up/Down, Home/End, and arrows; Command/Control/Option combinations are blocked |
| **Locked** | Input is blocked until the unlock or emergency sequence is detected |

Restricted and Locked both block mouse movement, clicks, dragging, and scrolling
delivered to the user-session event tap. Restricted can be escalated to Locked
with the lock sequence. Settings and Quit are available after returning to Default.
As in the original, allowed keys from the beginning of an unlock sequence can
reach the focused app in Restricted mode; the final triggering key is consumed.

## Settings

Click or right-click the menu bar lock and choose **Settings…**. `Command + ,`
also opens Settings while Padlock is the active app.

- **Key sequences:** Click **Record…**, type 1–10 keys with any modifiers, and
  click Save. Use Clear to restart. Tab, Return, Escape, and function keys can be
  recorded. Empty, duplicate, and overlapping prefix sequences are rejected.
- **Autolock (minutes):** Set a whole number from 0 to 1,440. **0 disables it**.
  A timer enters Locked mode after actual inactivity, including pointer movement.
- **Status box:** **Always show**, **Hide when unlocked**, or **Always hide**.
  A passive box sits at the lower right of each connected display, across Spaces.
- **Launch at login:** Uses macOS Login Items. Enable it after installing in
  Applications; approve it in Login Items if macOS requests approval.
- **Restore Defaults:** Restores the original sequences, disables autolock, and
  shows the status box. It keeps the current permission and login settings.

Key sequences identify physical keys and their Control/Option/Shift/Command
modifiers. Defaults are selected for the current keyboard layout on first use;
labels are translated with the active layout. After changing keyboard layouts,
review or re-record your sequences. Caps Lock state and Fn are not sequence
modifiers. Hold Fn where necessary to generate an actual function/navigation key
rather than a hardware media action.

While Settings is open, sequence actions and autolock are paused so editing a
sequence cannot lock you out. Use the menu's mode actions or close Settings to
resume. Settings are saved locally as you change them. A new app launch always
starts in Default mode.

## macOS behavior and recovery

Padlock is an input utility, not a replacement for macOS Lock Screen or account
authentication. Use macOS Lock Screen when protecting access to your Mac.

- macOS retains control of protected system shortcuts, power/Touch ID,
  loginwindow, and some hardware controls and trackpad gestures. A user-session
  event tap cannot guarantee filtering these paths or other privileged software.
- **Secure Keyboard Entry** can prevent global keyboard access. Padlock pauses
  blocking and autolock while macOS reports it active, and refuses to enter a
  blocking mode. Turn it off in the app that enabled it to resume.
- If permissions are removed, filtering is interrupted, the Mac sleeps, or the
  user session becomes inactive, Padlock returns to Default. It does not try to
  keep you locked when the unlock sequence cannot be received.
- If you forget a custom sequence, use **⌃⌥⌘Esc**. If macOS cannot deliver keyboard
  events, use its session/system controls or terminate Padlock from another
  session. Stopping the process removes its event tap; it does not persist a lock.
- A menu bar hidden by a notch, a full-screen app, or a menu manager does not
  prevent sequences from working. The corner status box is optional.
- Updating an ad-hoc signed app can require removing and re-adding its privacy
  permission entries. Quit the old version before replacing it.

## Privacy

No telemetry, accounts, analytics, update checks, input history, or app network
requests. Matching uses at most ten recent key strokes in memory. Settings store
only your configured sequences and preferences in macOS UserDefaults under
`io.github.pdgamersg.padlock`. A sequence is not a password and is not encrypted.
Opening system settings/help is an explicit user action.

## Build and continue development

Install Xcode or Apple's Command Line Tools with Swift 5.9 or later. No Homebrew
packages or third-party Swift dependencies are needed.

```bash
git clone https://github.com/PDGamerSG/padlock-mac.git
cd padlock-mac
./scripts/build.sh            # universal dist/Padlock.app
./scripts/build.sh arm64      # faster local build, Apple silicon only
./scripts/build.sh x86_64     # Intel only
./scripts/release.sh          # universal app, ZIP, DMG, and SHA256SUMS.txt
```

Open `Package.swift` in Xcode for source editing. The packaging script supplies
the app's Info.plist, icon, identity, and bundled documentation. Run the built
`.app` when testing permissions or launch at login; a bare `swift run` executable
does not have the same bundle identity. Build scripts **do not launch the app**.

Builds are ad-hoc signed by default. To sign with an existing Developer ID
certificate in your own keychain:

```bash
PADLOCK_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/release.sh
```

Developer ID signing alone does not notarize the app. Notarization and stapling
require your Apple Developer account and are separate from this initial release.

See [architecture](docs/ARCHITECTURE.md), [feature parity](docs/FEATURE-PARITY.md),
[build verification](https://github.com/PDGamerSG/padlock-mac/blob/main/docs/BUILD-VERIFICATION.md), and the
[manual testing checklist](docs/MANUAL-TESTING.md).

GitHub Actions builds the universal artifacts on pushes and pull requests. A
matching `v<version>` tag can publish a release. Workflows compile and package;
they do not execute runtime tests or interact with system input permissions.

## Verification status

The initial release was built with testing deferred. Subsequent verification
passed 28 configuration/persistence tests on arm64 and under Rosetta, 30 live
input checks, 25 repeated held-key cycles, and 14 native UI checks. **Full release
sign-off is incomplete:** the desktop locked before live idle testing finished,
and an earlier intermittent held-key observation needs continued monitoring.
See the [dated test report](docs/TEST-REPORT-2026-11-11.md) for evidence and limits.

Run `./scripts/test.sh` for the configuration/persistence suite. Interactive
tests are documented in [Tests/README.md](Tests/README.md); they require an
unlocked desktop and can briefly block input.

## License and credits

[BSD 3-Clause](LICENSE). Original Padlock © 2017 Daniel Teo.
macOS port © 2026 PDGamerSG and contributors.
See [third-party notices](THIRD-PARTY-NOTICES.md). This port is independent of
the original author and preserves the original copyright and license terms.
