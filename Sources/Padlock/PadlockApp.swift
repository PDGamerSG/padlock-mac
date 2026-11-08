import AppKit
import SwiftUI

@main
enum PadlockMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private lazy var model = AppModel()
    private var statusItem: NSStatusItem?
    private var overlay: StatusOverlay?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let identifier = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if let other = others.first {
                other.activate(options: [.activateIgnoringOtherApps])
                NSApp.terminate(nil)
                return
            }
        }
        installApplicationMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        overlay = StatusOverlay()
        model.onStateChanged = { [weak self] in self?.refreshUI() }
        model.onShowSettings = { [weak self] in self?.showSettings() }
        model.onHideSettings = { [weak self] in self?.settingsWindow?.close() }
        model.start()
        refreshUI()

        if !UserDefaults.standard.bool(forKey: "Padlock.hasOpened") || !model.ready {
            UserDefaults.standard.set(true, forKey: "Padlock.hasOpened")
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
        overlay?.close()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model.blocker.mode == .unlocked { showSettings() }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settingsWindow {
            model.setSettingsVisible(false)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        // Leave the button's action available for the next left/right click.
        statusItem?.menu = nil
    }

    @objc private func statusClicked(_ sender: Any?) {
        guard let item = statusItem else { return }
        if NSApp.currentEvent?.clickCount == 2, model.blocker.mode == .unlocked {
            showSettings()
            return
        }
        let menu = makeStatusMenu()
        item.menu = menu
        item.button?.performClick(nil)
    }

    @objc private func showSettings() {
        guard model.blocker.mode == .unlocked else { return }
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "Padlock Settings"
            window.minSize = NSSize(width: 600, height: 700)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.setFrameAutosaveName("Padlock.Settings")
            window.center()
            settingsWindow = window
        }
        model.setSettingsVisible(true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func restrictInput() { model.activate(.restricted) }
    @objc private func lockInput() { model.activate(.locked) }

    @objc private func quit() {
        guard model.blocker.mode == .unlocked else { return }
        NSApp.terminate(nil)
    }

    @objc private func openHelp() {
        if let url = Bundle.main.url(forResource: "README", withExtension: "md") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(string:
            "Native macOS port of Padlock by Daniel Teo (takuyakanbr).\n\n" +
            "Original © 2017 Daniel Teo.\nMac port © 2026 PDGamerSG and contributors.\n" +
            "BSD 3-Clause License. See the bundled LICENSE and THIRD-PARTY-NOTICES.\n\n" +
            "Input stays on your Mac. No telemetry or input history.\n" +
            "Emergency unlock: Control + Option + Command + Escape."
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Padlock for Mac",
            .credits: credits,
            .applicationIcon: NSImage(named: NSImage.applicationIconName) ?? NSImage()
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshUI() {
        let mode = model.blocker.mode
        let image = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: "Padlock: \(mode.title)")
        image?.isTemplate = mode == .unlocked
        statusItem?.button?.image = image
        statusItem?.button?.contentTintColor = mode == .unlocked ? nil : mode.color
        statusItem?.button?.toolTip = "Padlock: \(mode.title)\n\(model.availabilityText)"
        statusItem?.button?.setAccessibilityLabel("Padlock, \(mode.title). \(model.availabilityText)")
        overlay?.update(mode: mode, visibility: model.settings.statusVisibility)
        if let menu = statusItem?.menu {
            for item in menu.items {
                if item.action == #selector(showSettings) || item.action == #selector(quit) {
                    item.isEnabled = mode == .unlocked
                }
            }
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        let mode = model.blocker.mode
        add("Padlock — \(mode.title)", to: menu, enabled: false)
        add(model.availabilityText, to: menu, enabled: false)
        menu.addItem(.separator())
        add("Restrict Input   \(model.settings.title(for: .restrict))", action: #selector(restrictInput),
            to: menu, enabled: model.ready && mode == .unlocked)
        add("Lock Input   \(model.settings.title(for: .lock))", action: #selector(lockInput),
            to: menu, enabled: model.ready && mode != .locked)
        add("Unlock: \(model.settings.title(for: .unlock))", to: menu, enabled: false)
        menu.addItem(.separator())
        add("Settings…", action: #selector(showSettings), key: ",", to: menu, enabled: mode == .unlocked)
        add("Help", action: #selector(openHelp), to: menu, enabled: mode == .unlocked)
        add("About Padlock", action: #selector(showAbout), to: menu, enabled: mode == .unlocked)
        menu.addItem(.separator())
        add("Quit Padlock", action: #selector(quit), key: "q", to: menu, enabled: mode == .unlocked)
        return menu
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Padlock")
        appMenu.autoenablesItems = false
        add("About Padlock", action: #selector(showAbout), to: appMenu)
        appMenu.addItem(.separator())
        add("Settings…", action: #selector(showSettings), key: ",", to: appMenu)
        appMenu.addItem(.separator())
        add("Quit Padlock", action: #selector(quit), key: "q", to: appMenu)
        appItem.submenu = appMenu
        main.addItem(appItem)

        // SwiftUI text fields and selection use the standard responder chain.
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Undo", Selector(("undo:")), "z"),
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func add(_ title: String, action: Selector? = nil, key: String = "",
                     to menu: NSMenu, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
    }
}
