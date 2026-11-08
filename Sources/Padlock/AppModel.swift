import AppKit
import ApplicationServices
import Carbon
import Combine
import ServiceManagement

final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var mode = InputMode.unlocked
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var monitoringGranted = false
    @Published private(set) var secureInput = false
    @Published private(set) var ready = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    @Published var notice: String?
    @Published var recording: SequenceKind?

    var onStateChanged: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onHideSettings: (() -> Void)?

    let blocker: InputBlocker
    private let store = SettingsStore()
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var sessionInactive = false
    private var lastStartAttempt = -Double.infinity
    private var settingsVisible = false

    init() {
        let loaded = store.load()
        settings = loaded.settings
        notice = loaded.notice
        blocker = InputBlocker(settings: loaded.settings)
        blocker.onModeChange = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.mode = self.blocker.mode
                self.onStateChanged?()
            }
        }
        blocker.onFailure = { [weak self] message in
            DispatchQueue.main.async {
                self?.notice = message
                self?.refresh()
            }
        }
    }

    var availabilityText: String {
        if !accessibilityGranted || !monitoringGranted { return "Permissions needed" }
        if sessionInactive { return "Paused while the session is inactive" }
        if secureInput { return "Paused for Secure Keyboard Entry" }
        return ready ? "Input filtering ready" : "Input filtering unavailable"
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in self?.pauseSession() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in self?.pauseSession() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in self?.pauseSession() }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in self?.resumeSession() }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in self?.resumeSession() }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in self?.resumeSession() }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { [weak self] in
            self?.refresh()
        }
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        blocker.stop()
    }

    func refresh() {
        let access = AXIsProcessTrusted()
        let monitoring = CGPreflightListenEventAccess()
        let secure = IsSecureEventInputEnabled()
        var changed = access != accessibilityGranted || monitoring != monitoringGranted
            || secure != secureInput
        if access != accessibilityGranted { accessibilityGranted = access }
        if monitoring != monitoringGranted { monitoringGranted = monitoring }
        if secure != secureInput { secureInput = secure }

        if access && monitoring && !sessionInactive {
            let now = ProcessInfo.processInfo.systemUptime
            if !blocker.isRunning, now - lastStartAttempt >= 5 {
                lastStartAttempt = now
                if !blocker.start() {
                    notice = "macOS could not start input filtering. Confirm both permissions, then quit and reopen Padlock."
                }
            }
        } else {
            blocker.stop()
        }
        if secure || !blocker.isRunning { blocker.setMode(.unlocked) }
        let canFilter = access && monitoring && !secure && !sessionInactive && blocker.isRunning
        if canFilter != ready { ready = canFilter; changed = true }
        if blocker.mode != mode { mode = blocker.mode; changed = true }

        let status = SMAppService.mainApp.status
        let loginEnabled = status == .enabled || status == .requiresApproval
        let needsApproval = status == .requiresApproval
        if loginEnabled != launchAtLogin { launchAtLogin = loginEnabled }
        if needsApproval != loginNeedsApproval { loginNeedsApproval = needsApproval }
        blocker.checkIdle()
        if changed { onStateChanged?() }
    }

    func setSettingsVisible(_ visible: Bool) {
        settingsVisible = visible
        blocker.setConfiguring(visible)
        if !visible { recording = nil }
        onStateChanged?()
    }

    func activate(_ target: InputMode) {
        refresh()
        if target != .unlocked, !ready {
            notice = "Input filtering is unavailable. Review the permissions and status below."
            onShowSettings?()
            return
        }
        if settingsVisible { onHideSettings?() }
        blocker.setConfiguring(false)
        if !blocker.setMode(target) {
            notice = "Padlock could not change mode. Input remains available."
        }
    }

    @discardableResult
    func replaceSequence(_ kind: SequenceKind, with strokes: [KeyStroke]) -> String? {
        var updated = settings
        updated[kind] = strokes
        return save(updated)
    }

    func setAutoLock(_ minutes: Int) {
        var updated = settings
        updated.autoLockMinutes = minutes
        if let error = save(updated) { notice = error }
    }

    func setVisibility(_ visibility: StatusVisibility) {
        var updated = settings
        updated.statusVisibility = visibility
        if let error = save(updated) { notice = error }
    }

    func restoreDefaults() {
        if let error = save(.defaults) { notice = error }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }

    func requestMonitoring() {
        _ = CGRequestListenEventAccess()
        openPrivacy("Privacy_ListenEvent")
    }

    func openPrivacy(_ section: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(section)") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            notice = "Could not update launch at login: \(error.localizedDescription) Move Padlock.app to Applications and try again."
        }
        refresh()
    }

    func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }

    private func save(_ updated: AppSettings) -> String? {
        if let error = updated.validationError { return error }
        do {
            try store.save(updated)
            settings = updated
            blocker.update(settings: updated)
            onStateChanged?()
            return nil
        } catch { return error.localizedDescription }
    }

    private func pauseSession() {
        sessionInactive = true
        blocker.stop()
        refresh()
        onStateChanged?()
    }

    private func resumeSession() {
        sessionInactive = false
        lastStartAttempt = -Double.infinity
        blocker.resetActivity()
        refresh()
        onStateChanged?()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        observers.append((center, token))
    }
}
