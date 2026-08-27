import AppKit
import SwiftUI


enum MenuFocus: Hashable { case filter, formPrimary }

enum MenuSearch {
    static func items(for query: String, matching: (Reference) -> Bool = { _ in true }) -> [MenuItem] {
        Runtime.shared.search(query, limit: 60).all.compactMap { result in
            guard matching(result.ref), block(for: result.ref) != nil else { return nil }
            return MenuItem.reference(
                result.ref,
                name: result.name,
                description: result.description,
                tags: result.tags.sorted()
            )
        }.prefix(12).map { $0 }
    }

    static func block(for ref: Reference) -> Material.Block? {
        switch ref.type {
            case is Artifact.Type: return .artifact(ref)
            case is Command.Type: return .command(ref)
            case is Material.Type: return .material(ref)
            default: return nil
        }
    }
}

enum MenuSurface {
    static let menu: [MenuItem] = [
        MenuItem.command(id: "new-task", label: "Task", icon: "checkmark.circle", keywords: ["task", "todo"]),
        MenuItem.command(id: "new-link", label: "Link", icon: "link", keywords: ["link", "web", "url"]),
        MenuItem.divider("primary-divider"),
        MenuItem.command(id: "heading-1", label: "Heading 1", icon: "textformat.size", keywords: ["h1", "title"]),
        MenuItem.command(id: "heading-2", label: "Heading 2", icon: "textformat.size.smaller", keywords: ["h2", "subtitle"]),
        MenuItem.command(id: "heading-3", label: "Heading 3", icon: "textformat", keywords: ["h3"]),
        MenuItem.command(id: "bulleted-list", label: "Bulleted List", icon: "list.bullet", keywords: ["bullet", "list"]),
        MenuItem.command(id: "numbered-list", label: "Numbered List", icon: "list.number", keywords: ["number", "list"]),
        MenuItem.command(id: "checklist", label: "Checklist", icon: "checklist", keywords: ["todo", "checkbox"]),
        MenuItem.command(id: "quote", label: "Quote", icon: "quote.opening", keywords: ["blockquote"]),
        MenuItem.command(id: "code-block", label: "Code Block", icon: "curlybraces", keywords: ["code", "fence"]),
        MenuItem.divider("secondary-divider"),
        MenuItem.command(id: "add-files", label: "Files or Folders...", icon: "folder.badge.plus", keywords: ["file", "folder", "directory", "artifact", "open"])
    ]

    @MainActor static func build(for item: MenuItem) -> [Material.Block]? {
        guard let commandID = item.commandID else { return nil }

        switch commandID {
            case "add-files":
                let panel = NSOpenPanel()
                panel.title = "Add Files or Folders"
                panel.prompt = "Add"
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                guard panel.runModal() == .OK else { return nil }
                let entries = panel.urls.map { url in
                    let name = url.lastPathComponent.isEmpty ? "Artifact" : url.lastPathComponent
                    return Material.Block.artifact(Artifact.register(name, url))
                }
                return entries.isEmpty ? nil : entries
            case "heading-1": return [.text(UUID(), "# ")]
            case "heading-2": return [.text(UUID(), "## ")]
            case "heading-3": return [.text(UUID(), "### ")]
            case "bulleted-list": return [.text(UUID(), "- ")]
            case "numbered-list": return [.text(UUID(), "1. ")]
            case "checklist": return [.text(UUID(), "- [ ] ")]
            case "quote": return [.text(UUID(), "> ")]
            case "code-block": return [.text(UUID(), "```\n\n```")]
            default: return nil
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
                VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                    ForEach(items) { item in
                        if case .dividerItem = item {
                            Divider()
                                .opacity(Style.Opacity.muted)
                                .padding(.horizontal, Style.Spacing.lg)
                                .padding(.vertical, Style.Spacing.sm)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.medium

                            Button { onSelect(item) } label: {
                                RowLayout(
                                    title: Text(item.label)
                                        .font(Typography.row.weight(selected ? .medium : .regular))
                                        .foregroundColor(
                                            selected ? Style.Foreground.base : Style.Foreground.muted
                                        ),
                                    detail: item.detail.isEmpty ? nil : Text(item.detail)
                                        .font(Typography.caption.weight(.medium))
                                        .foregroundColor(Style.Foreground.disabled),
                                    spacerMinLength: .zero
                                ) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                } trailing: {
                                    if selected {
                                        Image(systemName: "return")
                                            .font(Typography.caption.weight(.medium))
                                            .foregroundStyle(Style.Foreground.faint)
                                    }
                                }
                                .padding(.horizontal, Style.Spacing.md)
                                .padding(.vertical, Style.Spacing.md)
                                .frame(minHeight: Style.Spacing.xxxl)
                                .background(
                                    shape.fill(
                                        selected
                                        ? Color.accentColor.opacity(Style.Opacity.muted)
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
                .foregroundStyle(Style.Foreground.base)

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
                focusValue: .formPrimary,
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
            .frame(height: Style.Spacing.xxxl)
            .background(
                Style.Shape.medium
                    .fill(Color.primary.opacity(Style.Opacity.hairline))
                    .overlay(
                        Style.Shape.medium
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
        .glassEffect(.regular, in: Style.Shape.large)
        .background(Style.Background.overlay)
        .overlay(Style.Shape.large.stroke(.black.opacity(Style.Opacity.muted), lineWidth: 1))
        .clipShape(Style.Shape.large)
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
        VStack {
            HStack(alignment: .center) {
                MenuFilterField(text: $text, onCommand: handle)
                    .padding(.vertical, Style.Spacing.md)
                    .padding(.horizontal, Style.Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Style.Background.raised)
            .clipShape(Style.Shape.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: Style.Spacing.xxxl)
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
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material):
                nil
            case .create, .update:
                    .formPrimary
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
        .padding(Style.Spacing.md)
        .glassEffect(.regular, in: Style.Shape.large)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .shadow(color: .black.opacity(0.2), radius: Style.Spacing.xl, y: Style.Spacing.md)
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
