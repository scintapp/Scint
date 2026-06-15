import SwiftUI
import AgencyRuntime


enum EditorSurface {
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

    @MainActor static func build(for item: MenuItem) -> [Sheet.Entry]? {
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
                return Sheet.Entry.artifact(Artifact.register(name, url))
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

struct Editor: View {
    @State var state: EditorModel

    init(ref: Reference) {
        _state = State(
            initialValue: EditorModel(
                sheet: ref,
                menu: MenuModel(items: EditorSurface.menu, makeEntries: EditorSurface.build(for:))
            )
        )
    }

    static func sheet(for workspace: Reference) -> Reference {
        guard let closure = Workspace.with(workspace, { $0.closure }) else { return Sheet.new("Workspace Composer", owner: workspace) }
        if let sheet = Closure.with(closure, { $0.sheets.first }) ?? nil { return sheet }
        let sheet = Sheet.new("Workspace Composer", owner: closure)
        Closure.update(closure) { if !$0.sheets.contains(sheet) { $0.sheets.append(sheet) } }
        return sheet
    }

    public var body: some View {
        EditorCanvas()
            .environment(state)
            .ignoresSafeArea(.container, edges: .top)
            .onAppear { state.ensureEditableTextBlock() }
    }
}
