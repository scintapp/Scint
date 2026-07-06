import AgencyRuntime
import SwiftUI


enum EditorMenuFocus: Hashable {
    case formPrimary
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

    @MainActor static func build(for item: MenuItem) -> [Sheet.Block]? {
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
                    return Sheet.Block.artifact(Artifact.register(name, url))
                }
                return entries.isEmpty ? nil : entries
            case "heading-1": return [.content(UUID(), "# ")]
            case "heading-2": return [.content(UUID(), "## ")]
            case "heading-3": return [.content(UUID(), "### ")]
            case "bulleted-list": return [.content(UUID(), "- ")]
            case "numbered-list": return [.content(UUID(), "1. ")]
            case "checklist": return [.content(UUID(), "- [ ] ")]
            case "quote": return [.content(UUID(), "> ")]
            case "code-block": return [.content(UUID(), "```\n\n```")]
            default: return nil
        }
    }
}

struct EditorMenuEmptyState: View {
    let title: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.quaternary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(width: width, height: height)
    }
}

@MainActor private func editorMenuTint(for symbol: String) -> Color {
    switch symbol {
    case "checkmark.circle", "checklist":
        Design.Tint.task
    case "link", "folder.badge.plus":
        Design.Tint.artifact
    case "textformat.size", "textformat.size.smaller", "textformat":
        Design.Tint.sheet
    case "quote.opening":
        Design.Tint.info
    case "curlybraces":
        Design.Tint.command
    default:
        Design.Tint.active
    }
}

@MainActor @ViewBuilder func editorMenuIcon(icon: String, selected: Bool, ref: Reference? = nil) -> some View {
    let symbol = icon.isEmpty ? "square.stack.3d.up" : icon
    let view = ref.map {
        Iconography.Icon(
            symbol: Iconography.symbol(for: $0),
            tint: Iconography.accent(for: $0),
            sizing: 18,
            selected: selected
        )
    } ?? Iconography.Icon(
        symbol: symbol,
        tint: editorMenuTint(for: symbol),
        sizing: 18,
        selected: selected
    )

    view
        .frame(width: 38, height: 38)
        .opacity(selected ? 1 : 0.88)
}

struct EditorMenuRow: View {
    @Environment(EditorState.self) private var editor
    private var menu: MenuModel { editor.menu }
    private var selected: Bool { item.id == menu.selectedID }
    let item: MenuItem
    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button {
            menu.select(item)
            editor.commitMenuSelection()
        } label: {
            HStack {
                if let ref = item.ref { editorMenuIcon(icon: "", selected: selected, ref: ref) }
                else if let icon = item.icon { editorMenuIcon(icon: icon, selected: selected) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 14.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.white.opacity(0.96) : Design.Foreground.primary)
                        .lineLimit(1)

                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(selected ? Color.white.opacity(0.65) : Design.Foreground.caption)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "return")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.82))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                shape.fill(selected ? Color.white.opacity(0.09) : Color.clear)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

struct EditorMenuList: View {
    @Environment(EditorState.self) private var editor

    private var menu: MenuModel { editor.menu }

    private var emptyTitle: String {
        switch menu.kind {
            case .command: return "No commands found"
            case .reference: return "No references found"
            case .form: return ""
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(menu.items) { item in
                        if case .dividerItem = item {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        } else {
                            EditorMenuRow(item: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .onChange(of: menu.selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    var body: some View {
        Group {
            if menu.items.isEmpty { EditorMenuEmptyState(title: emptyTitle, width: menu.size.width, height: menu.size.height) }
            else { list }
        }
        .glassEffect(.regular.tint(Design.Background.menu), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
    }
}

struct MenuForm: View {
    @Environment(EditorState.self) private var editor
    let kind: MenuFormKind
    let focus: FocusState<EditorMenuFocus?>.Binding

    private var menu: MenuModel { editor.menu }

    private var header: some View {
        HStack {
            Image(systemName: kind.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            Text(kind.title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var fields: some View {
        VStack(alignment: .leading) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: Binding(get: { menu.formPrimary }, set: { menu.formPrimary = $0 }),
                focusValue: .formPrimary,
                commit: { editor.commitMenuSelection() }
            )

            actions
        }
        .padding(12)
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel") { menu.close() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button("Insert") { editor.commitMenuSelection() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private func formField(placeholder: String, text: Binding<String>, focusValue: EditorMenuFocus, commit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Design.Background.menu)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
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
            Divider().overlay(Color.white.opacity(0.08))
            fields
        }
        .glassEffect(.regular.tint(Design.Background.menu), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
    }
}

struct EditorMenu: View {
    @Environment(EditorState.self) private var editor
    @FocusState private var focus: EditorMenuFocus?
    let position: CGPoint
    private var menu: MenuModel { editor.menu }

    @ViewBuilder private var content: some View {
        switch menu.kind {
            case .command, .reference:
                EditorMenuList()
            case .form(let kind):
                MenuForm(kind: kind, focus: $focus)
        }
    }

    private func focusInitialField(for kind: MenuKind) {
        switch kind {
            case .command, .reference:
                focus = nil
            case .form:
                focus = .formPrimary
        }
    }

    var body: some View {
        content
            .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
            .offset(x: position.x, y: position.y)
            .onChange(of: menu.kind) { _, kind in focusInitialField(for: kind) }
            .onAppear { focusInitialField(for: menu.kind) }
    }
}
