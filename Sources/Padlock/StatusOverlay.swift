import AppKit

/// Passive panels do not activate the application or intercept pointer events.
final class StatusOverlay {
    private var panels: [NSPanel] = []
    private var observer: NSObjectProtocol?
    private var mode = InputMode.unlocked
    private var visibility = StatusVisibility.always

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
        rebuild()
    }

    func update(mode: InputMode, visibility: StatusVisibility) {
        self.mode = mode
        self.visibility = visibility
        for panel in panels { update(panel) }
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    private func rebuild() {
        panels.forEach { $0.close() }
        panels = NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            let panel = NSPanel(
                contentRect: NSRect(x: frame.maxX - 140, y: frame.minY + 12, width: 128, height: 30),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.setAccessibilityLabel("Padlock input status")

            let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 128, height: 30))
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 7
            effect.layer?.masksToBounds = true

            let image = NSImageView()
            image.identifier = NSUserInterfaceItemIdentifier("modeIcon")
            image.translatesAutoresizingMaskIntoConstraints = false
            image.imageScaling = .scaleProportionallyDown
            let label = NSTextField(labelWithString: "")
            label.identifier = NSUserInterfaceItemIdentifier("modeLabel")
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(image)
            effect.addSubview(label)
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
                image.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 14),
                image.heightAnchor.constraint(equalToConstant: 14),
                label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8),
                label.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -10)
            ])
            panel.contentView = effect
            return panel
        }
        panels.forEach(update)
    }

    private func update(_ panel: NSPanel) {
        for view in panel.contentView?.subviews ?? [] {
            if let label = view as? NSTextField {
                label.stringValue = mode.title
                label.textColor = mode.color
            } else if let image = view as? NSImageView {
                image.image = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: mode.title)
                image.contentTintColor = mode.color
            }
        }
        if visibility == .never || (visibility == .whenBlocking && mode == .unlocked) {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
}
