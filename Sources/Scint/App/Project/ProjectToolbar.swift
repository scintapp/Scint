import SwiftUI
import ScintRuntime
import ScintComponents


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
                Image(systemName: "stop.fill")
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
                    ProjectControls(input: input, space: space, onCompose: compose, onCancel: cancel)
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

