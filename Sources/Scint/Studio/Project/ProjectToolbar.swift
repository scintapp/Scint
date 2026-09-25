import SwiftUI
import ScintRuntime
import ScintComponents


struct ProjectControls: View {
    var panel: any Panel
    var model: any Model
    var input: Reference
    var onStart: () -> Void

    @State var started: Bool = false

    var space: Reference? { model.session.selection.structure }

    var composable: Bool {
        guard let space else { return false }
        return Space.with(space, { $0.composable }) ?? false
    }

    var empty: Bool {
        return Document.with(input) { document in
            document.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
    }

    func start() {
        guard let space, composable, !empty else { return }
        Document.update(input) { $0.clear() }
        model.start(space)
        onStart()
    }

    func stop() {
        guard let space else { return }
        model.stop(space)
    }

    var working: Bool {
        guard let space, let composition = model.compose(space) else { return false }
        if case .working = composition.state { return true }
        return false
    }

    var body: some View {
        Button { started ? stop() : start() } label: {
            if started {
                Image(systemName: "stop.fill")
                    .font(Typography.footnote)
                    .foregroundStyle(Style.Background.canvas)
                    .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
                    .background(Style.Foreground.secondary, in: .circle)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(working ? nil : KeyboardShortcut(.return, modifiers: .command))
        .disabled(!composable || (!working && empty))
        .help(working ? "Pause" : "Send")
    }
}

struct ProjectToolbar: Surface {
    var panel: any Panel
    var model: any Model
    var onStart: () -> Void

    private var input: Reference? { model.session.input }
    private var space: Reference? { model.session.selection.structure }
    private var context: Context? { space?.context }
    private var harness: Reference? { space.flatMap { Space.with($0, { $0.harness }) ?? nil } }

    var body: some View {
        if let input {
            VStack(alignment: .leading, spacing: 8) {
                BlockList(document: input)
                    .id(input)
                    .frame(minHeight: 44, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                HStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 0)

                    if let context, context.state == .working {
                        StatusDot(context.intent.forms.running, tint: Iconography.tint(for: context.intent), isActive: true, size: 6)
                            .font(Typography.detail)
                            .foregroundStyle(Style.Foreground.secondary)
                    }
                    ProjectControls(panel: panel, model: model, input: input, onStart: onStart)
                }
                .frame(minHeight: Style.Dimension.control(.small))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: Typography.Prose.readableWidth)
            .background {
                Style.Shape.input
                    .fill(Style.Background.canvas.opacity(0.5))
                    .glassEffect(.regular.tint(Style.Background.canvas.opacity(0.75)), in: Style.Shape.input)
                    .blur(radius: 2, opaque: true)
                Style.Shape.input
                    .blendMode(.plusDarker)
            }
            .clipShape(Style.Shape.input)
            .overlay { Style.Shape.input.stroke(Style.Border.hairline, lineWidth: 1).opacity(0.25) }
        }
    }
}

