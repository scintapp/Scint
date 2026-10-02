import SwiftUI
import ScintRuntime
import ScintComponents


struct ContextTicker: View {
    var context: Context

    var run: (start: Date, stop: Date?)? {
        guard let started = context.started else { return nil }
        return (started, context.stopped.flatMap { $0 >= started ? $0 : nil })
    }

    var body: some View {
        if let run {
            TimelineView(.periodic(from: run.start, by: 1)) { timeline in
                Text(Duration.seconds(Int((run.stop ?? timeline.date).timeIntervalSince(run.start))).formatted(.units(width: .narrow, maximumUnitCount: 2)))
                    .monospacedDigit()
            }
        }
    }
}

struct ProjectControls: View {
    var input: Reference
    var space: Reference
    var onCompose: () -> Void
    var onCancel: () -> Void

    var composable: Bool { Runtime.shared.composable(space) }
    var context: Context? { space.context }
    var started: Bool { context?.state == .active ? true : false  }

    var working: Bool {
        guard let context else { return false }
        switch context.state {
            case .active, .working: return true
            default: return false
        }
    }

    var body: some View {
        Button { !working ? onCompose() : onCancel() } label: {
            if started {
                Image(systemName: "pause.fill")
                    .font(Typography.footnote)
                    .foregroundStyle(Style.Background.canvas)
                    .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
                    .background(Style.Foreground.secondary, in: .circle)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(working ? nil : KeyboardShortcut(.return, modifiers: .command))
        .disabled(!composable)
        .help(working ? "Pause" : "Send")
    }
}

struct ProjectFocus: NSViewRepresentable {
    @Binding var focused: Bool

    final class Anchor: NSView {
        var onChange: (Bool) -> Void = { _ in }
        private var observer: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = window.map { window in
                NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.update() }
                }
            }
        }

        private func update() {
            guard let responder = window?.firstResponder as? NSView else { return onChange(false) }
            onChange(convert(bounds, to: nil).contains(responder.convert(responder.visibleRect, to: nil)))
        }
    }

    func makeNSView(context: Self.Context) -> Anchor { Anchor() }

    func updateNSView(_ view: Anchor, context: Self.Context) {
        view.onChange = { if focused != $0 { focused = $0 } }
    }
}

struct ProjectIntent<Content: View>: View {
    var model: any Model
    @ViewBuilder var content: Content

    @State private var focused = false

    var context: Context? { model.session.selection.structure?.context }

    var tint: Color? {
        switch context?.state {
            case .active, .working: context.map { Iconography.tint(for: $0.intent).bright }
            default: nil
        }
    }

    var thought: String? {
        let branch = context?.transcript.flatMap { root in Transcript.with(root, { $0.branches.last }) ?? nil }
        let reasoning = branch.flatMap { branch in Transcript.with(branch, { transcript in transcript.records.last { $0.fields["channel"] == .string("reasoning") } }) ?? nil }
        guard case .string(let text)? = reasoning?.fields["content"] else { return nil }
        return ReasoningEntry(thoughts: [text]).lines.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let context, context.state == .working {
                HStack(spacing: 8) {
                    StatusDot(thought ?? context.intent.forms.running, tint: Iconography.tint(for: context.intent), isActive: true, size: 6)
                    ContextTicker(context: context)
                }
                .font(Typography.detail)
                .foregroundStyle(Style.Foreground.secondary)
                .lineLimit(1)
            }

            content
                .background { ProjectFocus(focused: $focused) }
                .overlay {
                    if let tint {
                        TimelineView(.animation) { timeline in
                            let head = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2

                            ZStack {
                                Style.Shape.input
                                    .stroke(tint.opacity(0.2), lineWidth: 1)

                                ForEach(0..<20, id: \.self) { step in
                                    let from = head - Double(step + 1) / 60
                                    let to = head - Double(step) / 60
                                    let fade = 1 - Double(step) / 20

                                    Style.Shape.input
                                        .trim(from: max(from, 0), to: max(to, 0))
                                        .stroke(tint.opacity(fade), lineWidth: 1)

                                    Style.Shape.input
                                        .trim(from: min(from + 1, 1), to: min(to + 1, 1))
                                        .stroke(tint.opacity(fade), lineWidth: 1)
                                }
                            }
                        }
                    }
                    else if focused {
                        Style.Shape.input
                            .stroke(Style.Border.surface, lineWidth: 1)
                    }
                }
        }
    }
}

struct ProjectToolbar: Surface {
    var panel: any Panel
    var model: any Model

    var composable: Bool {
        guard let space else { return false }
        return Space.with(space, { $0.composable }) ?? false
    }

    func compose() {
        guard let space, let input, composable else { return }
        Document.update(input) { $0.clear() }
        Space.update(space, { $0.input(input) })
        model.compose(space)
    }

    func cancel() {
        guard let space else { return }
        model.cancel(space)
    }

    private var input: Reference? { context?.input }
    private var space: Reference? { model.session.selection.structure }
    private var context: Context? { space?.context }
    private var harness: Reference? { space.flatMap { Space.with($0, { $0.harness }) ?? nil } }

    var body: some View {
        if let space, let input {
            VStack(alignment: .leading, spacing: 0) {
                BlockList(ref: input)
                    .id(input)
                    .frame(minHeight: 32, alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                HStack(alignment: .center, spacing: 0) {
                    Spacer(minLength: 0)
                    ProjectControls(input: input, space: space, onCompose: compose, onCancel: cancel)
                }
                .frame(minHeight: Style.Dimension.control(.small))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: Typography.Prose.readableWidth)
            .background {
                Style.Background.canvas
                    .blendMode(.sourceAtop)
                    .opacity(0.5)
            }
            .glassEffect(.regular.tint(Style.Background.canvas.opacity(0.5)), in: Style.Shape.input)

            .clipShape(Style.Shape.input)
            .overlay {
                Style.Shape.input
                    .stroke(Style.Border.panel, lineWidth: 1)
                    .opacity(0.5)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            }
        }
    }
}

