import SwiftUI


struct ComposeControl: View {
    var model: any Model
    var input: Reference
    var onSend: () -> Void

    var space: Reference? { model.session.selection.structure }

    var composable: Bool {
        guard let space else { return false }
        return Space.with(space, { $0.composable }) ?? false
    }

    var empty: Bool {
        return Material.with(input) { material in
            material.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
    }

    func send() {
        guard let space, composable, !empty else { return }
        Material.update(input) { $0.clear() }
        model.start(space)
        onSend()
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
                EditorView(
                    input,
                    sizing: .grows(min: Style.Spacing.inputMinHeight, max: Style.Spacing.inputMaxHeight),
                    autofocus: false,
                    onFocus: { model.select(input) },
                    onOpenLink: { link in
                        switch link {
                        case .reference(let ref): model.open(ref)
                        case .url(let url): NSWorkspace.shared.open(url)
                        }
                    }
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
