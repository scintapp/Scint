import AppKit
import ScintRuntime


@MainActor enum EditorMenu {
    static let menu: [MenuItem] = [
        MenuItem.command(id: "new-task", label: "Task", icon: "checkmark.circle", keywords: ["task", "todo"], opens: .task),
        MenuItem.command(id: "new-link", label: "Link", icon: "link", keywords: ["link", "web", "url"], opens: .link),
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

    static func search(_ query: String, kind: MenuKind) -> [MenuItem] {
        switch kind {
            case .dynamic:
                return SearchMenu.search(for: query) { Reference.Link.url(for: $0) != nil }
            case .update(let form):
                guard let type = referenceType(for: form) else { return [] }
                return SearchMenu.search(for: query, filters: [String(describing: type)])
            case .fixed, .create:
                return []
        }
    }

    static func commit(_ outcome: MenuOutcome, editor: ScintEditor) {
        guard outcome.isInserting else { return }
        switch outcome.choice {
        case .item(let item):
            if let ref = item.ref, let link = Reference.Link.markdown(for: ref, name: item.label) { editor.replace(outcome.replacementRange, with: link) }
            else if let blocks = build(for: item) { editor.insert(blocks, replacing: outcome.replacementRange) }
        case .form(.task, let values):
            let value = values.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            editor.insert([.task(UUID(), value.isEmpty ? "Task" : value, values.completed, nil)], replacing: outcome.replacementRange)
        case .form(.link, let values):
            guard let url = normalizedURL(from: values.primary.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let link = Reference.Link.markdown(for: Artifact.new(url.host(percentEncoded: false) ?? url.absoluteString, url)) else { return }
            editor.replace(outcome.replacementRange, with: link)
        case .form(.artifact, _), .form(.command, _), .form(.document, _): break
        }
    }

    private static func referenceType(for form: MenuFormKind) -> (any Any.Type)? {
        switch form {
            case .artifact: return Artifact.self
            case .command: return Command.self
            case .document: return Document.self
            case .task, .link: return nil
        }
    }

    static func build(for item: MenuItem) -> [Document.Block]? {
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
                    return Document.Block.artifact(Artifact.new(name, url))
                }
                return entries.isEmpty ? nil : entries
            default: return nil
        }
    }

    private static func normalizedURL(from value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://\(value)")
    }
}
