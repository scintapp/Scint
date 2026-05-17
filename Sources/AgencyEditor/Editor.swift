import AppKit
import SwiftUI
import AgencyRuntime


enum EditorSurface {
    static let menu: [MenuItem] = [
        .init(id: "new-task", label: "Task", icon: "checkmark.circle", keywords: ["task", "todo"]),
        .init(id: "new-link", label: "Link", icon: "link", keywords: ["link", "web", "url"]),
        .divider("primary-divider"),
        .init(id: "heading-1", label: "Heading 1", icon: "textformat.size", keywords: ["h1", "title"]),
        .init(id: "heading-2", label: "Heading 2", icon: "textformat.size.smaller", keywords: ["h2", "subtitle"]),
        .init(id: "heading-3", label: "Heading 3", icon: "textformat", keywords: ["h3"]),
        .init(id: "bulleted-list", label: "Bulleted List", icon: "list.bullet", keywords: ["bullet", "list"]),
        .init(id: "numbered-list", label: "Numbered List", icon: "list.number", keywords: ["number", "list"]),
        .init(id: "checklist", label: "Checklist", icon: "checklist", keywords: ["todo", "checkbox"]),
        .init(id: "quote", label: "Quote", icon: "quote.opening", keywords: ["blockquote"]),
        .init(id: "code-block", label: "Code Block", icon: "curlybraces", keywords: ["code", "fence"]),
        .divider("secondary-divider"),
        .init(id: "add-files", label: "Files or Folders...", icon: "folder.badge.plus", keywords: ["file", "folder", "directory", "artifact", "open"])
    ]

    @MainActor static func build(for item: MenuItem) -> [Sheet.Entry]? {
        switch item.id {
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

        case "heading-1":
            return [.text(UUID(), "# ")]
        case "heading-2":
            return [.text(UUID(), "## ")]
        case "heading-3":
            return [.text(UUID(), "### ")]
        case "bulleted-list":
            return [.text(UUID(), "- ")]
        case "numbered-list":
            return [.text(UUID(), "1. ")]
        case "checklist":
            return [.text(UUID(), "- [ ] ")]
        case "quote":
            return [.text(UUID(), "> ")]
        case "code-block":
            return [.text(UUID(), "```\n\n```")]

        default:
            return nil
        }
    }
}

struct AgencyEditor: View {
    @State var state: EditorModel
    let ref: Reference
    let mode: EditorCanvas.Mode
    let onSubmit: (() -> Void)?
    let onActivate: ((Entry) -> Void)?

    @MainActor init(
        ref: Reference,
        mode: EditorCanvas.Mode = .document,
        onSubmit: (() -> Void)? = nil,
        onActivate: ((Entry) -> Void)? = nil
    ) {
        self.ref = ref
        self.mode = mode
        self.onSubmit = onSubmit
        self.onActivate = onActivate

        let activateExternalEntry: (Entry) -> Void = { entry in
            if let onActivate {
                onActivate(entry)
                return
            }
            if case .artifact(let ref) = entry,
               let url = Artifact.with(ref, { $0.entry.url }).flatMap({ $0 }) {
                NSWorkspace.shared.open(url)
            }
        }

        _state = State(
            initialValue: EditorModel(
                sheet: SheetModel(ref: ref),
                menuItems: EditorSurface.menu,
                makeEntries: EditorSurface.build(for:),
                activateExternalEntry: activateExternalEntry)
        )
    }

    public var body: some View {
        EditorCanvas(mode: mode, onSubmit: onSubmit)
            .environment(state)
            .onChange(of: state.sheet.dirty) { _, dirty in if dirty { state.sheet.sync() } }
            .onDisappear { if state.sheet.dirty { state.sheet.sync() } }
    }
}
