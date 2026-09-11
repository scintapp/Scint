import AppKit
import SwiftUI


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
                sizing: Style.Spacing.xl
            )
            .frame(width: Style.Spacing.xxl, height: Style.Spacing.xxl)

            Text(kind.title(updating: updating))
                .font(Typography.row.weight(.medium))
                .foregroundStyle(Style.Foreground.primary)

            Spacer()
        }
        .padding(.horizontal, Style.Spacing.md)
        .padding(.vertical, Style.Spacing.md)
    }

    var fields: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.lg) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: $primary,
                focusValue: .form,
                commit: onCommit
            )

            actions
        }
        .padding(Style.Spacing.lg)
    }

    var actions: some View {
        HStack(spacing: Style.Spacing.md) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.badge)
                .foregroundStyle(Style.Foreground.disabled)
            Button(action: onCommit) {
                Text(updating ? "Update" : "Insert")
                    .font(Typography.badge)
                    .foregroundStyle(Style.Foreground.faint)
                    .padding(.horizontal, Style.Spacing.md)
                    .frame(height: Style.Spacing.xxl)
                    .background(Color.primary.opacity(Style.Opacity.hairline))
                    .clipShape(Style.Shape.capsule)
                    .overlay {
                        Style.Shape.capsule
                            .strokeBorder(
                                Color.primary.opacity(Style.Opacity.hairline),
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
            .font(Typography.row.weight(.medium))
            .foregroundStyle(Style.Foreground.muted)
            .padding(.horizontal, Style.Spacing.md)
            .frame(height: Style.Spacing.xxl)
            .background(
                Style.Shape.tiny
                    .fill(Color.primary.opacity(Style.Opacity.hairline))
                    .overlay(
                        Style.Shape.tiny
                            .stroke(
                                Color.primary.opacity(Style.Opacity.hairline),
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
            Divider().opacity(Style.Opacity.faint)
            fields
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .glassEffect(.regular.tint(Style.Background.overlay), in: Style.Shape.tiny)
    }
}

struct MenuFilterField: NSViewRepresentable {
    @Binding var text: String
    let onCommand: (Selector) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Self.Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.placeholderString = "Filter"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = Typography.appKitRow
        field.textColor = NSColor(Style.Foreground.faint)
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

        func focus(_ field: NSTextField, attempts: Int = 3) {
            guard field.currentEditor() == nil else { return }
            guard let window = field.window, window.makeFirstResponder(field) else { retry(field, attempts: attempts); return }
        }

        func retry(_ field: NSTextField, attempts: Int) {
            guard attempts > 0 else { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field else { return }
                self.focus(field, attempts: attempts - 1)
            }
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
        switch selector {
            case #selector(NSResponder.moveDown(_:)):
                onMoveSelection(1)
            case #selector(NSResponder.moveUp(_:)):
                onMoveSelection(-1)
            case #selector(NSResponder.insertNewline(_:)):
                onCommit()
            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()
            case #selector(NSResponder.deleteBackward(_:)) where text.isEmpty:
                onCancel()
            default:
                return false
        }
        return true
    }

    var body: some View {
        HStack(alignment: .center) {
            MenuFilterField(text: $text, onCommand: handle)
                .padding(.leading, Style.Spacing.sm)
        }
        .padding(.horizontal, Style.Spacing.xs)
        .padding(.vertical, Style.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Style.Spacing.rowDetailHeight, alignment: .leading)
        .background(Style.Shape.tiny.fill(Style.Background.form))
        .contentShape(Style.Shape.tiny)
        .padding(.top, Style.Spacing.xs)
    }
}

struct MenuList: View {
    let items: [MenuItem]
    let selectedID: String?
    let onSelect: (MenuItem) -> Void

    var body: some View {
        ScrollView(.vertical) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                    ForEach(items) { item in
                        if case .divider = item {
                            Divider()
                                .opacity(Style.Opacity.muted)
                                .padding(.horizontal, Style.Spacing.lg)
                                .padding(.vertical, Style.Spacing.sm)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.tiny

                            Button { onSelect(item) } label: {
                                GroupRow(
                                    title: Text(item.label)
                                        .font(Typography.row.weight(selected ? .medium : .regular))
                                        .foregroundColor(
                                            selected ? Style.Foreground.primary : Style.Foreground.secondary
                                        ),
                                    detail: item.detail.isEmpty ? nil : Text(item.detail)
                                        .font(Typography.caption.weight(.medium))
                                        .foregroundColor(Style.Foreground.muted),
                                    spacerMinLength: .zero
                                ) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                        .padding(.leading, Style.Spacing.xs)
                                } trailing: {
                                    if selected {
                                        Image(systemName: "return")
                                            .font(Typography.caption.weight(.medium))
                                            .foregroundStyle(Style.Foreground.subtle)
                                            .padding(.trailing, Style.Spacing.xs)
                                    }
                                }
                                .padding(.horizontal, Style.Spacing.xs)
                                .padding(.vertical, Style.Spacing.sm)
                                .frame(minHeight: Style.Spacing.xxl)
                                .background(
                                    shape.fill(
                                        selected
                                        ? Color.accentColor.opacity(Style.Opacity.faint)
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
                    withAnimation(.easeOut(duration: Style.Duration.menuSelection)) {
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
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material): nil
            case .create, .update: .form
        }
    }

    private var emptyTitle: String {
        switch kind {
            case .fixed: return "No commands found"
            case .dynamic, .update(.artifact), .update(.command), .update(.material): return "No references found"
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
                    EmptyState(title: emptyTitle, width: size.width, height: size.height)
                } else {
                    MenuList(items: items, selectedID: selectedID, onSelect: onSelect)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Style.Spacing.md)
        .padding(.vertical, Style.Spacing.sm)
        .glassEffect(.regular.tint(Style.Background.group), in: Style.Shape.tiny)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .scrollIndicators(.hidden)
    }

    var body: some View {
        Group {
            switch kind {
                case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material):
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
        .task(id: kind) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            focus.wrappedValue = initialFocus
        }
    }
}
