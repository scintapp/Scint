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
                Text(Duration.seconds(Int((run.stop ?? timeline.date)
                    .timeIntervalSince(run.start)))
                    .formatted(.units(width: .narrow, maximumUnitCount: 2)))
            }
        }
    }
}

struct CommandTrack: View {
    var stops: Int
    var selected: Int?
    var onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let step = (geometry.size.width - 16) / CGFloat(max(stops - 1, 1))
            let center = geometry.size.height / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Style.Background.surface)
                    .frame(height: 10)

                if let selected {
                    Capsule()
                        .fill(Style.Foreground.secondary)
                        .frame(width: 16 + CGFloat(selected) * step, height: 10)
                }

                ForEach(0..<stops, id: \.self) { index in
                    Circle()
                        .fill(Style.Foreground.primary.opacity(0.35))
                        .frame(width: 3, height: 3)
                        .position(x: 8 + CGFloat(index) * step, y: center)
                }

                if let selected {
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                        .position(x: 8 + CGFloat(selected) * step, y: center)
                }
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                onSelect(min(max(Int(((drag.location.x - 8) / step).rounded()), 0), stops - 1))
            })
        }
        .frame(height: 16)
    }
}

struct CommandOption: View {
    var name: String
    var selected = false
    var disclosure = false
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name)
                    .foregroundStyle(Style.Foreground.primary)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Style.Foreground.secondary)
                }
                if disclosure {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Style.Foreground.secondary)
                }
            }
            .font(Typography.detail)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 28)
            .background(hovered ? Style.Background.surface : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct CommandHeader: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
            }
            .font(Typography.detail)
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ProjectCommand: Surface {
    var host: any Host
    var model: any Model

    @State private var presented = false
    @State private var hovered = false
    @State private var page: Page = .summary
    @State private var forward = true

    enum Page: Hashable {
        case summary, providers, models(Reference)

        var depth: Int {
            switch self {
                case .summary: 0
                case .providers: 1
                case .models: 2
            }
        }
    }

    var space: Reference? { model.session.selection.structure }
    var harness: Reference? { space.flatMap { Space.with($0, { $0.harness }) ?? nil } }
    var inputs: [(name: String, schema: Schema)] { harness.flatMap { Harness.with($0, { harness in harness.signatures[.start].map { ([$0] + harness.parameters).inputs(config) } }) ?? nil } ?? [] }
    var command: Reference? { slot.flatMap { config[$0]?.references.first } }
    var settings: [ItemParams] { SettingsGroup.parameters(model).sections.flatMap(\.items) }
    var range: ItemParams? { settings.first { $0.trailingKind == .range } }
    var models: ItemParams? { settings.first { $0.key == "model" } }

    var input: Reference? { space.flatMap { Space.with($0, { $0.input }) } }
    var config: [String: Value] { harness.flatMap { harness in input.flatMap { Document.with($0, { $0.values(harness) }) } } ?? [:] }

    var slot: String? { inputs.first.flatMap { if case .command = $0.schema.bare { $0.name } else { nil } } }

    var providers: [Reference] {
        Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .filter { $0.descriptor.tags.contains("provider") }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private func configure(_ value: Value?, for key: String, of ref: Reference?) {
        guard let input, let ref else { return }
        Document.update(input) { $0.metadata(value, key, for: ref) }
    }

    private func choices(_ provider: Reference) -> [String] {
        let model = Command.with(provider, { $0.parameters.inputs().first { $0.name == "model" } }) ?? nil
        return model?.schema.choices.compactMap(\.rendered.last) ?? []
    }

    private func go(_ next: Page) {
        forward = next.depth > page.depth
        DispatchQueue.main.async { withAnimation(.snappy(duration: 0.25)) { page = next } }
    }

    private func choose(_ provider: Reference, _ value: String?) {
        if let slot { configure(.reference(provider), for: slot, of: harness) }
        configure(value.map { .property(.string($0)) }, for: "model", of: provider)
        go(.summary)
    }

    var body: some View {
        if let _ = harness {
            Button { presented.toggle() } label: {
                Image(systemName: "switch.2")
                    .font(.system(size: 15))
                    .foregroundStyle(Style.Foreground.primary)
                    .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
                    .background(hovered ? Style.Background.selection : .clear, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .help("Command")
            .popover(isPresented: $presented, arrowEdge: .top) {
                ZStack(alignment: .top) {
                    switch page {
                        case .summary:
                            VStack(spacing: 10) {
                                VStack(spacing: 1) {
                                    Text(range?.description ?? command?.descriptor.name ?? "Default")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(range?.value?.isEmpty == false ? Style.Foreground.primary : Style.Foreground.secondary)

                                    Button { go(.providers) } label: {
                                        HStack(spacing: 2) {
                                            Text(models?.value?.isEmpty == false ? models?.description ?? "" : command?.descriptor.name ?? "Default")
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 9, weight: .semibold))
                                        }
                                        .font(Typography.detail)
                                        .foregroundStyle(Style.Foreground.secondary)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                if let range, let key = range.key {
                                    CommandTrack(stops: range.items.count, selected: range.items.firstIndex { $0.value == range.value }) { index in
                                        configure(range.items[index].value.map { .property(.string($0)) }, for: key, of: range.origin)
                                    }
                                }
                            }
                            .padding(12)
                            .transition(.push(from: forward ? .trailing : .leading))

                        case .providers:
                            VStack(alignment: .leading, spacing: 2) {
                                CommandHeader(title: "Select model") { go(.summary) }

                                ForEach(providers, id: \.self) { provider in
                                    CommandOption(name: provider.descriptor.name, selected: provider == command, disclosure: true) {
                                        go(.models(provider))
                                    }
                                }
                            }
                            .padding(6)
                            .transition(.push(from: forward ? .trailing : .leading))

                        case .models(let provider):
                            VStack(alignment: .leading, spacing: 2) {
                                CommandHeader(title: provider.descriptor.name) { go(.providers) }

                                CommandOption(name: "Default", selected: provider == command && models?.value?.isEmpty != false) {
                                    choose(provider, nil)
                                }

                                ForEach(choices(provider), id: \.self) { value in
                                    CommandOption(name: Argument.label(value), selected: provider == command && models?.value == value) {
                                        choose(provider, value)
                                    }
                                }
                            }
                            .padding(6)
                            .transition(.push(from: forward ? .trailing : .leading))
                    }
                }
                .frame(width: 220)
                .fixedSize(horizontal: false, vertical: true)
                .clipped()
            }
            .onChange(of: presented) { _, shown in if !shown { page = .summary } }
        }
    }
}

struct ProjectControls: View {
    var input: Reference
    var space: Reference
    var onCompose: () -> Void
    var onCancel: () -> Void

    var composable: Bool { Runtime.shared.resolve(space) != nil }
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
            Image(systemName: working ? "pause.fill" : "arrow.up")
                .font(Typography.footnote)
                .foregroundStyle(Style.Background.canvas)
                .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
                .background(Style.Foreground.secondary, in: .circle)
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
    @State private var focused = false
    @ViewBuilder var content: Content

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
                    StatusDot(thought ?? context.intent.forms.running, tint: Iconography.tint(for: context.intent), isActive: true, size: 8)
                    ContextTicker(context: context)
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.subtle)
                        .lineLimit(1)
                }

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
                }
        }
    }
}

struct ProjectToolbar: Surface {
    var host: any Host
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
                EditorDocument(ref: input)
                    .id(input)
                    .frame(minHeight: 32, alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                HStack(alignment: .center, spacing: 8) {
                    Spacer(minLength: 0)
                    ProjectCommand(host: host, model: model)
                    ProjectControls(input: input, space: space, onCompose: compose, onCancel: cancel)
                }
                .frame(minHeight: Style.Dimension.control(.regular))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
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
                    .stroke(Style.Border.frame, lineWidth: 1)
                    .opacity(0.5)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            }
        }
    }
}

