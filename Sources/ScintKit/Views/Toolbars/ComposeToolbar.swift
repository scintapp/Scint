import SwiftUI


struct ComposeControl: View {
    var model: any Model
    var input: Reference
    var onSend: () -> Void

    var origin: Reference { model.session.origin }

    var composable: Bool {
        Space.with(origin, { $0.composable }) ?? false
    }

    var empty: Bool {
        return Material.with(input) { material in
            material.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
    }

    func send() {
        guard composable, !empty else { return }
        Material.update(input) { $0.clear() }
        model.start(origin)
        onSend()
    }

    func stop() {
        model.stop(origin)
    }

    var working: Bool {
        guard let composition = model.compose(origin) else { return false }
        if case .working = composition.state { return true }
        return false
    }

    var body: some View {
        Button { working ? stop() : send() } label: {}
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
            VStack(alignment: .leading) {
                EditorComponent(
                    input,
                    autofocus: false,
                    active: model.session.selection.content == input,
                    minHeight: Style.Spacing.inputMinHeight,
                    maxHeight: Style.Spacing.inputMaxHeight,
                    onFocus: { _ in model.select(input) }
                )
                .id(input)
                .padding(.horizontal, Style.Spacing.lg)
                .padding(.top, Style.Spacing.lg)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: 660)
            .overlay(alignment: .trailing) { ComposeControl(model: model, input: input, onSend: onSend) }
            .background {
                Style.Shape.medium
                    .fill(Style.Background.card.opacity(0.5))
                    .glassEffect(.regular, in: Style.Shape.medium)
                    .blur(radius: 2)
                Style.Shape.medium
                    .fill(Style.Background.card.opacity(0.5))
            }
            .overlay {
                Style.Shape.medium
                    .stroke(Style.Border.card.opacity(0.75), lineWidth: 1, antialiased: true)
            }
            .clipShape(Style.Shape.medium)
        }
    }
}
