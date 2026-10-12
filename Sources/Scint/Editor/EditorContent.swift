import SwiftUI


struct EditorContent: View {
    @State var focus: EditorFocus = .init()
    @State var textValues: [EditorFocus.Item.ID: String]
    @FocusState var keyboardFocusID: EditorFocus.Item.ID?

    init(textValues: [EditorFocus.Item.ID : String] = [:], keyboardFocusID: EditorFocus.Item.ID? = nil) {
        self.textValues = textValues
        self.keyboardFocusID = keyboardFocusID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Selected: \(selectedTitle)")
                    .font(.headline)

                Spacer()

                Menu("Insert") {
                    Button("Editor Below", systemImage: "text.cursor") { insert(.editor) }
                    Button("Block Below", systemImage: "square") { insert(.block)}
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            VStack(spacing: 10) {
                ForEach(focus.rows) { row in
                    if row.isNested {
                        HStack(spacing: 8) {
                            ForEach(row.items) { item in
                                component(item)
                            }
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.secondary.opacity(0.25))
                        }
                    } else if let item = row.items.first {
                        component(item)
                    }
                }
            }
        }
        .padding(20)
        .onChange(of: focus.selectedID, initial: true) { _, id in
            keyboardFocusID = id
        }
    }

    @ViewBuilder func component(_ item: EditorFocus.Item) -> some View {
        if item.isEditor {
            ZStack(alignment: .topTrailing) {
                TextEditor(
                    text: textBinding(for: item.id),
                    isFocused: focus.selectedID == item.id,
                    onFocus: { select(item.id) },
                    onMovePastBoundary: { offset in
                        focus.moveSelection(id: item.id, offset: offset)
                    }
                )

                Button {
                    textValues[item.id] = nil
                    focus.delete(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(7)
                .accessibilityLabel("Remove \(item.title)")
            }
            .frame(height: 105)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        focus.selectedID == item.id ? Color.accentColor : .secondary.opacity(0.35),
                        lineWidth: focus.selectedID == item.id ? 3 : 1
                    )
                    .allowsHitTesting(false)
            }
        } else {
            FocusableButtonSurface(
                id: item.id,
                title: item.title,
                isSelected: focus.selectedID == item.id,
                keyboardFocusID: $keyboardFocusID,
                onFocus: { select(item.id) },
                onMoveSelection: { offset in focus.moveSelection(id: item.id, offset: offset) },
                onClose: { focus.delete(id: item.id) }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 110)
        }
    }

    var selectedTitle: String {
        focus.items.first(where: { $0.id == focus.selectedID })?.title ?? "None"
    }

    func select(_ id: EditorFocus.Item.ID) {
        guard focus.items.contains(where: { $0.id == id }) else { return }
        focus.selectedID = id
    }

    func insert(_ kind: EditorFocus.Item.Kind) {
        let id = focus.insert(kind)
        if kind == .editor {
            textValues[id] = "New Editor\n\nUse the arrow keys to move between blocks."
        }
    }

    func textBinding(for id: EditorFocus.Item.ID) -> Binding<String> {
        Binding(get: { textValues[id, default: ""] }, set: { textValues[id] = $0 })
    }
}
