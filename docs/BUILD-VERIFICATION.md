# Initial release build verification

Version: **1.0.0**. Recorded **2026-11-09**.

## Scope

The user requested a complete project and public release and explicitly deferred
testing. Verification in this session was limited to compilation, static source
review, package metadata, signatures, architecture/load commands, disk-image
integrity, and file checksums. **Padlock was not launched, input permissions were
not requested, and no automated or runtime tests were run.**

UI behavior, actual input filtering, permission transitions, launch at login,
Intel execution, and older macOS execution remain unverified. Use the unchecked
[manual testing checklist](MANUAL-TESTING.md) in the next session.

## Build environment

- Apple silicon host, macOS **27.0.1**, build **26A434**.
- Standalone Apple Command Line Tools; full Xcode was not installed.
- Apple Swift **6.4**, Swift 5 language mode, macOS **27.0 SDK**.
- Deployment target **macOS 13.0** for both `arm64` and `x86_64`.
- No third-party Swift packages or runtime dependencies.

## Recorded results

| Inspection | Result |
| --- | --- |
| `./scripts/release.sh` | Exit 0; both optimized architectures compiled and linked, universal app/ZIP/DMG created |
| `lipo -archs` on executable | `x86_64 arm64` |
| `otool -l` build-version commands | `minos 13.0`, `sdk 27.0` in both slices |
| `otool -L` | System frameworks and Swift runtime libraries; no developer-machine library paths |
| `codesign --verify --strict --verbose=2` | Valid on disk; satisfies designated requirement |
| `codesign --display --verbose=4` | `io.github.pdgamersg.padlock`; universal Mach-O; `Signature=adhoc`; no TeamIdentifier |
| `plutil -lint` on source/bundled Info.plist | Both OK |
| `bash -n scripts/build.sh scripts/release.sh` | Exit 0 |
| `hdiutil verify` | Disk-image checksum VALID |
| ZIP entry listing | App executable, metadata, icon, signature, license, notices, README, and help/checklist included |
| `shasum -a 256 -c SHA256SUMS.txt` | ZIP OK; DMG OK |
| GitHub repository visibility | PUBLIC at `PDGamerSG/padlock-mac` |

## Toolchain notices

The current SwiftPM toolchain deprecates the `native` build-system selector; it
still completes the build and supports the older Swift toolchains used by CI.
The current SDK's `State` macro depends on a SwiftUI plugin absent from standalone
Command Line Tools; the source explicitly selects the original State property
wrapper through a type alias.

When cross-linking Intel, this standalone toolchain warns that its optional
`libswiftCompatibilityPacks.a` archive contains only arm64/arm64e. The x86_64
executable links successfully and does not load that archive. This is not
evidence of Intel or old-OS runtime compatibility; those checks remain deferred.
The current macOS tools also deprecate the `hdiutil create` spelling, but image
creation and checksum verification succeed. Build scripts retain compatibility
with macOS 13 and the older CI toolchains.

## Distribution

Assets: `Padlock-1.0.0-universal.dmg`, `Padlock-1.0.0-universal.zip`, and
`SHA256SUMS.txt`. The application and disk image include the original BSD license.
The initial app is **ad-hoc signed, not Developer ID signed or notarized**.
Gatekeeper may require **Privacy & Security → Open Anyway**, and the user must
grant Accessibility and Input Monitoring before activating blocking modes.
