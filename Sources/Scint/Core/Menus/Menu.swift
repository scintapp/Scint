import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


final class MenuFilterTextField: NSTextField {
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
}

struct MenuForm: View {
    @Binding var primary: String
    let kind: MenuFormKind
    let updating: Bool
    let size: CGSize
    let focus: FocusState<MenuFocus?>.Binding
    let onCancel: () -> Void
    let onCommit: () -> Void

    var header: some View {
        HStack {
            Iconography.Icon(
                symbol: kind.icon,
                tint: Iconography.menuTint(for: kind),
                sizing: Metrics.rowIcon
            )
            .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))

            Text(kind.title(updating: updating))
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Style.Foreground.primary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    var fields: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.heading) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: $primary,
                focusValue: .form,
                commit: onCommit
            )

            actions
        }
        .padding(2)
    }

    var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.detail)
                .foregroundStyle(Style.Foreground.secondary)
            Button(action: onCommit) {
                Text(updating ? "Update" : "Insert")
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: Style.Dimension.control(.small))
                    .background(Style.Background.surface)
                    .clipShape(Style.Shape.card)
                    .overlay {
                        Style.Shape.card
                            .strokeBorder(
                                Style.Background.surface,
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
        }
    }

    func formField(placeholder: String, text: Binding<String>, focusValue: MenuFocus, commit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Typography.body.weight(.medium))
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 8)
            .frame(height: Style.Dimension.control(.small))
            .background(
                Style.Shape.control
                    .fill(Style.Background.surface)
                    .overlay(
                        Style.Shape.control
                            .stroke(
                                Style.Background.surface,
                                lineWidth: 1
                            )
                    )
            )
            .focused(focus, equals: focusValue)
            .onKeyPress(.return) {
                commit()
                return .handled
            }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            header
            Divider().opacity(Style.Opacity.outline)
            fields
        }
        .frame(width: 280, height: 400, alignment: .top)
        .glassEffect(.regular, in: Style.Shape.control)
    }
}

struct MenuFilterField: NSViewRepresentable {
    @Binding var text: String
    let onCommand: (Selector) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Self.Context) -> NSTextField {
        let field = MenuFilterTextField(string: text)
        field.delegate = context.coordinator
        field.placeholderString = "Filter"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = NSColor(Style.Foreground.secondary)
        field.usesSingleLineMode = true
        return field
    }

    func updateNSView(_ field: NSTextField, context: Self.Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.focus(field)
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MenuFilterField

        init(_ parent: MenuFilterField) { self.parent = parent }

        func focus(_ field: NSTextField) {
            guard field.currentEditor() == nil, let window = field.window else { return }
            window.makeFirstResponder(field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            parent.onCommand(selector)
        }
    }
}

struct MenuFilter: View {
    @Binding var text: String
    let onMoveSelection: (Int) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    func handle(_ selector: Selector) -> Bool {
        switch NSStringFromSelector(selector) {
            case "moveDown:", "insertTab:": onMoveSelection(1)
            case "moveUp:", "insertBacktab:": onMoveSelection(-1)
            case "insertNewline:": onCommit()
            case "cancelOperation:": onCancel()
            case "deleteBackward:" where text.isEmpty: onCancel()
            default: return false
        }
        return true
    }

    var body: some View {
        HStack(alignment: .center) {
            MenuFilterField(text: $text, onCommand: handle)
        }
    }
}

struct MenuList: View {
    let items: [MenuItem]
    let selectedID: String?
    let onSelect: (MenuItem) -> Void

    var body: some View {
        ScrollView(.vertical) {
            ScrollViewReader { proxy in
                VStack {
                    ForEach(items) { item in
                        if case .divider = item {
                            Divider()
                                .opacity(Style.Opacity.inactive)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.control

                            let title = Text(item.label)
                                .font(.system(size: 13))
                                .foregroundColor(Style.Foreground.primary)

                            let detail = item.detail.isEmpty ? nil : Text(item.detail)
                                .font(.system(size: 11.5))
                                .foregroundColor(Style.Foreground.secondary)

                            Button { onSelect(item) } label: {
                                GroupRow(title: title, detail: detail, spacerMinLength: .zero) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                        .saturation(selected ? 1.0 : 0.0)
                                        .padding(.leading, 6)
                                } trailing: {
                                    if selected {
                                        Image(systemName: "return")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Style.Foreground.secondary)
                                            .padding(.trailing, 6)
                                    }
                                }
                                .padding(.vertical, 6)
                                .frame(minHeight: 14)
                                .background(
                                    shape
                                        .fill(selected ? Style.Background.selection : Color.clear)
                                )
                                .contentShape(shape)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: selectedID) { _, newID in
                    guard let newID else { return }
                    withAnimation(Metrics.menuSelection) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

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
