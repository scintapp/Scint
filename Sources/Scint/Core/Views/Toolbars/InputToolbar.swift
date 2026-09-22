import SwiftUI
import ScintRuntime
import ScintComponents


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
        return Document.with(input) { document in
            document.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
    }

    func send() {
        guard let space, composable, !empty else { return }
        Document.update(input) { $0.clear() }
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

struct InputToolbar: View {
    var model: any Model
    var onSend: () -> Void

    private var input: Reference? { model.session.input }

    var body: some View {
        if let input {
            VStack(alignment: .leading) {
                EditorView(input)
                .id(input)
                .padding(.horizontal, 12)
                .padding(.top, 16)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: 660)
            .overlay(alignment: .trailing) { ComposeControl(model: model, input: input, onSend: onSend) }
            .background {
                Style.Shape.card
                    .fill(Style.Background.surface.opacity(0.25))
                    .glassEffect(.clear, in: Style.Shape.card)
                    .opacity(0.25)
                Style.Shape.card
                    .fill(Style.Background.surface.opacity(0.5))
            }
            .overlay {
                Style.Shape.card
                    .strokeBorder(Style.Border.hairline, lineWidth: 1).opacity(0.35)
            }
            .clipShape(Style.Shape.card)
        }
    }
}
