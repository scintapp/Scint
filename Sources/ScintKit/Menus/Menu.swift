import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


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
        .padding(.horizontal, Style.Spacing.label)
        .padding(.vertical, Style.Spacing.label)
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
        .padding(Style.Spacing.inset)
    }

    var actions: some View {
        HStack(spacing: Style.Spacing.label) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.detail)
                .foregroundStyle(Style.Foreground.tertiary)
            Button(action: onCommit) {
                Text(updating ? "Update" : "Insert")
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .padding(.horizontal, Style.Spacing.label)
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
            .padding(.horizontal, Style.Spacing.label)
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
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .glassEffect(.regular.tint(Style.Background.surface), in: Style.Shape.control)
    }
}

final class MenuFilterTextField: NSTextField {
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
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
                .padding(.leading, Style.Spacing.detail)
        }
        .padding(.horizontal, Style.Spacing.detail)
        .padding(.vertical, Style.Spacing.detail)
        .frame(maxWidth: .infinity, minHeight: Metrics.rowDetailHeight, alignment: .leading)
        .background(Style.Shape.control.fill(Style.Background.surface))
        .contentShape(Style.Shape.control)
        .padding(.top, Style.Spacing.detail)
    }
}

struct MenuList: View {
    let items: [MenuItem]
    let selectedID: String?
    let onSelect: (MenuItem) -> Void

    var body: some View {
        ScrollView(.vertical) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                    ForEach(items) { item in
                        if case .divider = item {
                            Divider()
                                .opacity(Style.Opacity.inactive)
                                .padding(.horizontal, Style.Spacing.inset)
                                .padding(.vertical, Style.Spacing.detail)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.control

                            Button { onSelect(item) } label: {
                                GroupRow(
                                    title: Text(item.label)
                                        .font(Typography.body.weight(selected ? .medium : .regular))
                                        .foregroundColor(
                                            selected ? Style.Foreground.primary : Style.Foreground.primary
                                        ),
                                    detail: item.detail.isEmpty ? nil : Text(item.detail)
                                        .font(Typography.detail.weight(.medium))
                                        .foregroundColor(Style.Foreground.secondary),
                                    spacerMinLength: .zero
                                ) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                        .padding(.leading, Style.Spacing.detail)
                                } trailing: {
                                    if selected {
                                        Image(systemName: "return")
                                            .font(Typography.detail.weight(.medium))
                                            .foregroundStyle(Style.Foreground.secondary)
                                            .padding(.trailing, Style.Spacing.detail)
                                    }
                                }
                                .padding(.horizontal, Style.Spacing.detail)
                                .padding(.vertical, Style.Spacing.detail)
                                .frame(minHeight: Style.Dimension.control(.small))
                                .background(
                                    shape.fill(
                                        selected
                                        ? Color.accentColor.opacity(Style.Opacity.outline)
                                        : Color.clear
                                    )
                                )
                                .contentShape(shape)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: selectedID) { _, newID in
                    guard let newID else { return }
                    withAnimation(Metrics.menuSelection) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
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
                if items.isEmpty {
                    NoReference(title: emptyTitle)
                } else {
                    MenuList(items: items, selectedID: selectedID, onSelect: onSelect)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Style.Spacing.label)
        .padding(.vertical, Style.Spacing.detail)
        .glassEffect(.regular.tint(Style.Background.surface), in: Style.Shape.control)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .scrollIndicators(.hidden)
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
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .offset(x: position.x, y: position.y)
        .onAppear { focus.wrappedValue = initialFocus }
        .onChange(of: kind) { _, _ in focus.wrappedValue = initialFocus }
    }
}
