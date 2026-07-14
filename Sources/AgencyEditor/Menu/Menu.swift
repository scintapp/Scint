import AgencyRuntime
import SwiftUI


@MainActor private func menuTint(for symbol: String) -> Color {
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

@MainActor @ViewBuilder func menuIcon(icon: String, selected: Bool, ref: Reference? = nil) -> some View {
    let symbol = icon.isEmpty ? "square.stack.3d.up" : icon
    let view = ref.map {
        Iconography.Icon(
            symbol: Iconography.symbol(for: $0),
            tint: Iconography.accent(for: $0),
            sizing: 20,
            selected: true
        )
    } ?? Iconography.Icon(
        symbol: symbol,
        tint: menuTint(for: symbol),
        sizing: 20,
        selected: true
    )

    view
        .frame(width: 32, height: 32)
        .opacity(selected ? 1 : 0.92)
}

enum MenuFocus: Hashable {
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

struct MenuEmptyState: View {
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

struct MenuRow: View {
    @Environment(EditorState.self) private var editor
    private var menu: MenuModel { editor.menu }
    private var selected: Bool { item.id == menu.selectedID }
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
                        .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Design.Foreground.primary : Design.Foreground.secondary)
                        .lineLimit(1)

                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Design.Foreground.disabled)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "return")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Design.Foreground.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 46)
            .background(
                shape.fill(selected ? Design.Foreground.quaternary.opacity(0.24) : Color.clear)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

struct MenuList: View {
    @Environment(EditorState.self) private var editor

    private var menu: MenuModel { editor.menu }

    private var emptyTitle: String {
        switch menu.kind {
            case .fixed: return "No commands found"
            case .dynamic, .update(.artifact), .update(.command), .update(.sheet): return "No references found"
            case .create, .update: return ""
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(menu.items) { item in
                        if case .dividerItem = item {
                            Divider()
                                .opacity(0.34)
                                .padding(.leading, 54)
                                .padding(.vertical, 4)
                        } else {
                            MenuRow(item: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
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
            if menu.items.isEmpty { MenuEmptyState(title: emptyTitle, width: menu.size.width, height: menu.size.height) }
            else { list }
        }
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
//        .background(Design.Background.block.opacity(0.44))
//        .glassEffect(.regular.tint(Design.Background.menu), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(.regular, in: Design.Shape.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
        }
    }
}

struct MenuForm: View {
    @Environment(EditorState.self) private var editor
    let kind: MenuFormKind
    let updating: Bool
    let focus: FocusState<MenuFocus?>.Binding

    private var menu: MenuModel { editor.menu }

    private var header: some View {
        HStack {
            Iconography.Icon(symbol: kind.icon, tint: menuTint(for: kind.icon), sizing: 16)
                .frame(width: 26, height: 26)

            Text(kind.title(updating: updating))
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Design.Foreground.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var fields: some View {
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

    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel") { menu.close() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Design.Foreground.disabled)
            Button {
                editor.commitMenuSelection()
            } label: {
                Text(updating ? "Update" : "Insert")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.tertiary)
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

    private func formField(placeholder: String, text: Binding<String>, focusValue: MenuFocus, commit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Design.Foreground.secondary)
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
//        .background(Design.Background.block.opacity(0.44))
        .glassEffect(.regular, in: Design.Shape.card)
        .clipShape(Design.Shape.card)
        .overlay {
            Design.Shape.card
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
        }
    }
}

struct Menu: View {
    @Environment(EditorState.self) private var editor
    @FocusState private var focus: MenuFocus?
    let position: CGPoint
    private var menu: MenuModel { editor.menu }

    @ViewBuilder private var content: some View {
        switch menu.kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.sheet):
                MenuList()
            case .create(let kind):
                MenuForm(kind: kind, updating: false, focus: $focus)
            case .update(let kind):
                MenuForm(kind: kind, updating: true, focus: $focus)
        }
    }

    private func focusInitialField(for kind: MenuKind) {
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.sheet):
                focus = nil
            case .create, .update:
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
