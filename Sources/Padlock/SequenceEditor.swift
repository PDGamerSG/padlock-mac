import AppKit
import SwiftUI

struct SequenceEditor: View {
    @ObservedObject var model: AppModel
    let kind: SequenceKind
    @Environment(\.dismiss) private var dismiss
    @ViewState private var strokes: [KeyStroke] = []
    @ViewState private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Record \(kind.rawValue) sequence").font(.title2.weight(.semibold))
            Text("Type 1–10 keys, then click Save. Hold modifiers with each key, just as you will when using the sequence.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(strokes.isEmpty ? "Waiting for keys…" : strokes.map(\.title).joined(separator: "  "))
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.horizontal, 14)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor.opacity(0.6)))
                .accessibilityLabel("Recorded sequence")
                .accessibilityValue(strokes.isEmpty ? "No keys" : strokes.map(\.title).joined(separator: ", "))
            HStack {
                Text("\(strokes.count) of 10 keys").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { strokes = []; error = nil }.disabled(strokes.isEmpty)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("All keys, including Tab, Return, and Escape, are recorded here. Use the buttons to save or cancel.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if let message = model.replaceSequence(kind, with: strokes) { error = message }
                    else { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(strokes.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(KeyCapture { stroke in
            guard stroke.isValid else {
                error = "That key is reserved or unsupported. Choose another key."
                return
            }
            guard strokes.count < 10 else {
                error = "A sequence can contain up to 10 keys. Click Clear to start again."
                return
            }
            strokes.append(stroke)
            error = nil
        }.frame(width: 0, height: 0))
    }
}

private struct KeyCapture: NSViewRepresentable {
    let onKey: (KeyStroke) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) { nsView.onKey = onKey }
    static func dismantleNSView(_ nsView: CaptureView, coordinator: ()) { nsView.stop() }

    final class CaptureView: NSView {
        var onKey: ((KeyStroke) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, window.isKeyWindow,
                      event.window === window else { return event }
                if !event.isARepeat { self.onKey?(KeyStroke(event: event)) }
                return nil
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { stop() }
    }
}
