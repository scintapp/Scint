import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct Menu: View {
    @Binding var query: String
    @Binding var formPrimary: String
    let kind: MenuKind
    let items: [MenuItem]
    let selectedID: String?
    let size: CGSize
    let position: CGPoint
    let focus: FocusState<MenuFocus?>.Binding
    let onMoveSelection: (Int) -> Void
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void

    private var initialFocus: MenuFocus? {
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.document): nil
            case .create, .update: .form
        }
    }

    private var emptyTitle: String {
        switch kind {
            case .fixed: return "No commands found"
            case .dynamic, .update(.artifact), .update(.command), .update(.document): return "No references found"
            case .create, .update: return ""
        }
    }

    private var list: some View {
        VStack {
            MenuFilter(
                text: $query,
                onMoveSelection: onMoveSelection,
                onCommit: onCommit,
                onCancel: onCancel
            )

            Group {
                if items.isEmpty { NoReference(title: emptyTitle) }
                else { MenuList(items: items, selectedID: selectedID, onSelect: onSelect) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(width: 280, alignment: .top)
    }

    var body: some View {
        Group {
            switch kind {
                case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.document):
                    list
                case .create(let form):
                    MenuForm(
                        primary: $formPrimary,
                        kind: form,
                        updating: false,
                        size: size,
                        focus: focus,
                        onCancel: onCancel,
                        onCommit: onCommit
                    )
                case .update(let form):
                    MenuForm(
                        primary: $formPrimary,
                        kind: form,
                        updating: true,
                        size: size,
                        focus: focus,
                        onCancel: onCancel,
                        onCommit: onCommit
                    )
            }
        }
        .frame(width: 280, alignment: .top)
        .offset(x: position.x, y: position.y)
        .onAppear { DispatchQueue.main.async { focus.wrappedValue = initialFocus } }
        .onChange(of: kind) { _, _ in DispatchQueue.main.async { focus.wrappedValue = initialFocus } }
    }
}
