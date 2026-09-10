import SwiftUI


struct ComposeControl: View {
    var model: any Model
    var input: Reference
    var onSend: () -> Void

    private var origin: Reference { model.session.origin }

    private var composable: Bool {
        Space.with(origin, { $0.composable })
        ?? Workspace.with(origin, { $0.composable })
        ?? false
    }

    private var empty: Bool {
        return Material.with(input) { material in
            material.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
    }

    private func send() {
        guard composable, !empty else { return }
        Material.update(input) { $0.clear() }
        model.start(origin)
        onSend()
    }

    private func stop() {
        model.stop(origin)
    }

    private var working: Bool {
        guard let composition = model.compose(origin) else { return false }
        if case .working = composition.state { return true }
        return false
    }

    var body: some View {
        Button { working ? stop() : send() } label: {
            Image(systemName: working ? "pause" : "return")
                .font(.system(size: Style.Dimension.icon))
                .foregroundStyle(Style.Foreground.subtle)
                .frame(width: Style.Dimension.control, height: Style.Dimension.control, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(working ? nil : KeyboardShortcut(.return, modifiers: .command))
        .disabled(!composable || (!working && empty))
        .help(working ? "Pause" : "Send")
    }
}

struct ComposeBar: View {
    var model: any Model
    var onSend: () -> Void

    private var input: Reference? { model.session.input }

    var body: some View {
        if let input {
            ZStack(alignment: .topLeading) {
                EditorComponent(
                    input,
                    autofocus: false,
                    active: model.session.selected.content == input,
                    minHeight: Style.Spacing.inputMinHeight,
                    maxHeight: Style.Spacing.inputMaxHeight,
                    onFocus: { _ in model.select(input) }
                )
                .id(input)
                .padding(.horizontal, Style.Spacing.lg)
                .padding(.top, Style.Spacing.lg)
            }
            .overlay(alignment: .trailing) {
                ComposeControl(model: model, input: input, onSend: onSend)
            }
            .background(Style.Shape.medium.fill(Style.Background.raised))
            .overlay(Style.Shape.medium.stroke(Style.Border.base, lineWidth: 0.5, antialiased: true))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}
