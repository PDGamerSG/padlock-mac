Native macOS port of [takuyakanbr/padlock](https://github.com/takuyakanbr/padlock).

- Default, Restricted, and Locked modes with global keyboard/pointer filtering.
- Original defaults: Option+R, Option+L, and `asdf` to unlock.
- Editable 1–10-key sequences, idle locking, and all three status box options.
- Native menu bar controls, settings, per-display status, and launch at login.
- Emergency unlock: **Control+Option+Command+Escape**.
- Input remains local; no telemetry, accounts, or third-party runtime dependencies.
- Universal **Apple silicon + Intel**, **macOS 13+**.

Download the **DMG**, drag Padlock into Applications, and grant **Accessibility**
and **Input Monitoring**. A ZIP and SHA-256 checksums are also attached.

**Signing:** Ad-hoc signed; not Developer ID signed or notarized. If macOS blocks
the app, attempt to open it, then use **System Settings → Privacy & Security →
Open Anyway**. Updates can require refreshing privacy permission entries.

**Verification:** Compilation and package inspection only. The app was not
launched, no input permissions were requested, and no runtime or automated tests
were executed, as requested. See `docs/MANUAL-TESTING.md` for the next session.

**Platform limits:** Protected input, system-reserved controls, power/Touch ID,
and some hardware gestures remain under macOS control. Padlock pauses for Secure
Keyboard Entry and returns to Default when filtering is unavailable. It does
not replace macOS Lock Screen.

BSD 3-Clause. Original © 2017 Daniel Teo; macOS port © 2026 PDGamerSG and contributors.
