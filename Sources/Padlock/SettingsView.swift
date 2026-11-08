import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ViewState private var restoreConfirmation = false
    @ViewState private var idleText = ""
    @ViewState private var idleError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: model.mode.symbol)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(model.ready ? Color.accentColor : .secondary)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Padlock").font(.title2.weight(.semibold))
                    Text(model.availabilityText).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.mode.title).font(.callout.weight(.medium))
                    .foregroundStyle(Color(nsColor: model.mode.color))
            }
            .padding(22)

            Divider()
            Form {
                if let notice = model.notice {
                    Section {
                        HStack(alignment: .top) {
                            Label(notice, systemImage: "info.circle")
                                .font(.callout).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Button { model.notice = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("Dismiss message")
                        }
                    }
                }

                Section {
                    permissionRow("Accessibility", granted: model.accessibilityGranted,
                                  action: model.requestAccessibility)
                    permissionRow("Input Monitoring", granted: model.monitoringGranted,
                                  action: model.requestMonitoring)
                    if model.secureInput {
                        Text("Secure Keyboard Entry is active in another app. Padlock stays in Default mode until it is turned off.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Permissions") } footer: {
                    Text("Enable Padlock in both privacy lists to filter input. If macOS asks, quit and reopen Padlock after granting access.")
                }

                Section {
                    ForEach(SequenceKind.allCases) { kind in
                        HStack {
                            Text(kind.title).frame(width: 120, alignment: .leading)
                            Text(model.settings.title(for: kind))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Record…") { model.recording = kind }
                                .accessibilityLabel("Record \(kind.title.lowercased())")
                        }
                    }
                } header: { Text("Key sequences") } footer: {
                    Text("Type the unlock sequence anywhere to return to Default. Sequences can contain up to 10 keys with modifiers. Locking is paused while Settings is open.")
                }

                Section {
                    HStack {
                        Text("Autolock (minutes)")
                        Spacer()
                        TextField("0", text: $idleText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 76)
                            .onSubmit(commitIdle)
                            .onChange(of: idleText) { value in
                                if let minutes = Int(value), (0...1440).contains(minutes) {
                                    idleError = nil
                                    model.setAutoLock(minutes)
                                } else {
                                    idleError = "Enter a whole number from 0 to 1,440."
                                }
                            }
                            .accessibilityLabel("Autolock after minutes of inactivity")
                    }
                    if let idleError { Text(idleError).font(.caption).foregroundStyle(.red) }
                    Picker("Status box", selection: Binding(
                        get: { model.settings.statusVisibility }, set: model.setVisibility
                    )) {
                        ForEach(StatusVisibility.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin }, set: model.setLaunchAtLogin
                    ))
                    if model.loginNeedsApproval {
                        HStack {
                            Text("Allow Padlock in Login Items to finish setup.").font(.caption)
                            Spacer()
                            Button("Open Login Items", action: model.openLoginItems)
                        }
                    }
                } header: { Text("Behavior") } footer: {
                    Text("0 disables autolock. Keyboard, mouse, and trackpad activity reset the timer. The status box appears at the lower right of each display.")
                }

                Section {
                    HStack {
                        Label("Emergency unlock", systemImage: "lifepreserver")
                        Spacer()
                        Text("⌃⌥⌘Esc").font(.system(.body, design: .monospaced))
                    }
                    Text("Control + Option + Command + Escape always returns to Default while Padlock can receive keyboard events. This shortcut cannot be changed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Restore Defaults…") { restoreConfirmation = true }
                Spacer()
                Text("An input lock for your Mac").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
        }
        .frame(minWidth: 580, idealWidth: 600, maxWidth: .infinity,
               minHeight: 660, idealHeight: 740, maxHeight: .infinity)
        .onAppear { idleText = String(model.settings.autoLockMinutes) }
        .onChange(of: model.settings.autoLockMinutes) { value in
            if Int(idleText) != value { idleText = String(value) }
        }
        .sheet(item: $model.recording) { kind in SequenceEditor(model: model, kind: kind) }
        .confirmationDialog("Restore the original key sequences and behavior settings?",
                            isPresented: $restoreConfirmation) {
            Button("Restore Defaults", role: .destructive) { model.restoreDefaults() }
        } message: { Text("Launch at login and macOS permissions will keep their current values.") }
    }

    private func permissionRow(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .accessibilityLabel(granted ? "Granted" : "Not granted")
            Text(title)
            Spacer()
            if granted { Text("Allowed").foregroundStyle(.secondary) }
            else { Button("Allow…", action: action) }
        }
    }

    private func commitIdle() {
        guard let minutes = Int(idleText), (0...1440).contains(minutes) else {
            idleText = String(model.settings.autoLockMinutes)
            idleError = nil
            return
        }
        model.setAutoLock(minutes)
    }
}
