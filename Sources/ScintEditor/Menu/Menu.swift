import AppKit
import SwiftUI


@MainActor func menuTint(for symbol: String) -> Color {
    switch symbol {
        case "checkmark.circle", "checklist":
            Style.Tint.task
        case "link", "folder.badge.plus":
            Style.Tint.artifact
        case "textformat.size", "textformat.size.smaller", "textformat":
            Style.Tint.material
        case "quote.opening":
            Style.Tint.info
        case "curlybraces":
            Style.Tint.command
        default:
            Style.Tint.active
    }
}

@MainActor @ViewBuilder func menuIcon(icon: String, selected: Bool, ref: Reference? = nil) -> some View {
    let symbol = icon.isEmpty ? "square.stack.3d.up" : icon
    let view = ref.map {
        Iconography.Icon(
            symbol: Iconography.symbol(for: $0),
            tint: Iconography.accent(for: $0),
            sizing: 16,
            selected: true
        )
    } ?? Iconography.Icon(
        symbol: symbol,
        tint: menuTint(for: symbol),
        sizing: 16,
        selected: true
    )

    view
        .frame(width: 24, height: 24)
        .opacity(selected ? 1 : 0.92)
}

enum MenuFocus: Hashable { case filter, formPrimary }

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

struct MenuRow: View {
    @Environment(EditorState.self) var editor
    var menu: MenuModel { editor.menu }
    var selected: Bool { item.id == menu.selectedID }
    let item: MenuItem
    let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)

    var body: some View {
        Button {
            menu.select(item)
            editor.commitMenuSelection()
        } label: {
            HStack(alignment: .center) {
                if let ref = item.ref { menuIcon(icon: "", selected: selected, ref: ref) }
                else if let icon = item.icon { menuIcon(icon: icon, selected: selected) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 13, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Style.Foreground.primary : Style.Foreground.secondary)
                        .lineLimit(1)

                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Style.Foreground.disabled)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "return")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Style.Foreground.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(shape.fill(selected ? .accent.opacity(0.6) : Color.clear))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

struct MenuList: View {
    @Environment(EditorState.self) var editor

    var menu: MenuModel { editor.menu }

    var query: Binding<String> {
        Binding(get: { menu.query }, set: { menu.query = $0 })
    }

    var filter: some View {
        MenuFilter(text: query)
    }

    var emptyTitle: String {
        switch menu.kind {
            case .fixed: return "No commands found"
            case .dynamic, .update(.artifact), .update(.command), .update(.material): return "No references found"
            case .create, .update: return ""
        }
    }

    var list: some View {
        ScrollView(.vertical) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(menu.items) { item in
                        if case .dividerItem = item {
                            Divider()
                                .opacity(0.5)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        } else {
                            MenuRow(item: item)
                                .id(item.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: menu.selectedID) { _, newID in
                    guard let newID else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack {
            filter

            Group {
                if menu.items.isEmpty {
                    EmptyState(title: emptyTitle, width: menu.size.width, height: menu.size.height)
                } else {
                    list
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(Style.Background.menu)
        .overlay(Style.Shape.menu.stroke(.black.opacity(0.5), lineWidth: 0.5))
        .clipShape(Style.Shape.menu)
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .glassEffect(.regular, in: Style.Shape.menu)
        .scrollIndicators(.hidden)
    }
}

struct MenuForm: View {
    @Environment(EditorState.self) var editor
    let kind: MenuFormKind
    let updating: Bool
    let focus: FocusState<MenuFocus?>.Binding

    var menu: MenuModel { editor.menu }

    var header: some View {
        HStack {
            Iconography.Icon(symbol: kind.icon, tint: menuTint(for: kind.icon), sizing: 16)
                .frame(width: 24, height: 24)

            Text(kind.title(updating: updating))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Style.Foreground.primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: Binding(get: { menu.formPrimary }, set: { menu.formPrimary = $0 }),
                focusValue: .formPrimary,
                commit: { editor.commitMenuSelection() }
            )

            actions
        }
        .padding(14)
    }

    var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel") { menu.close() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Style.Foreground.disabled)
            Button {
                editor.commitMenuSelection()
            } label: {
                Text(updating ? "Update" : "Insert")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Style.Foreground.tertiary)
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    func formField(placeholder: String, text: Binding<String>, focusValue: MenuFocus, commit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.075), lineWidth: 0.75)
                    )
            )
            .focused(focus, equals: focusValue)
            .onKeyPress(.return) {
                commit()
                return .handled
            }
            .onKeyPress(.escape) {
                menu.close()
                return .handled
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.42)
            fields
        }
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
        .glassEffect(.regular, in: Style.Shape.menu)
        .background(Style.Background.menu)
        .overlay(Style.Shape.menu.stroke(.black.opacity(0.5), lineWidth: 0.5))
        .clipShape(Style.Shape.menu)
    }
}

struct MenuFilter: View {
    @Environment(EditorState.self) var editor
    @Binding var text: String

    var menu: MenuModel { editor.menu }

    func handle(_ selector: Selector) -> Bool {
        switch selector {
            case #selector(NSResponder.moveDown(_:)):
                menu.moveSelection(1)
            case #selector(NSResponder.moveUp(_:)):
                menu.moveSelection(-1)
            case #selector(NSResponder.insertNewline(_:)):
                editor.commitMenuSelection()
            case #selector(NSResponder.cancelOperation(_:)):
                menu.close()
            case #selector(NSResponder.deleteBackward(_:)) where text.isEmpty:
                menu.close()
            default:
                return false
        }
        return true
    }

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                MenuFilterField(text: $text, onCommand: handle)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Style.Background.raised)
            .clipShape(Style.Shape.block)
        }
        .frame(maxWidth: .infinity, maxHeight: 38)
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
        field.font = .systemFont(ofSize: 13)
        field.textColor = NSColor(Style.Foreground.tertiary)
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

struct Menu: View {
    @Environment(EditorState.self) var editor
    @FocusState var focus: MenuFocus?
    var menu: MenuModel { editor.menu }
    let position: CGPoint

    func focusInitialField(for kind: MenuKind) {
        let target: MenuFocus?
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material):
                target = nil
            case .create, .update:
                target = .formPrimary
        }

        Task { @MainActor in
            await Task.yield()
            guard menu.kind == kind else { return }
            focus = target
        }
    }

    var body: some View {
        Group {
            switch menu.kind {
                case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material):
                    MenuList()
                case .create(let kind):
                    MenuForm(kind: kind, updating: false, focus: $focus)
                case .update(let kind):
                    MenuForm(kind: kind, updating: true, focus: $focus)
            }
        }
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
        .offset(x: position.x, y: position.y)
        .onChange(of: menu.kind) { _, kind in focusInitialField(for: kind) }
        .onAppear { focusInitialField(for: menu.kind) }
    }
}
