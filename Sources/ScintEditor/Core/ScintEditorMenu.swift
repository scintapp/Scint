import AppKit


@MainActor enum ScintEditorMenu {
    static let menu: [MenuItem] = [
        MenuItem.command(id: "new-task", label: "Task", icon: "checkmark.circle", keywords: ["task", "todo"], opens: .task),
        MenuItem.command(id: "new-link", label: "Link", icon: "link", keywords: ["link", "web", "url"], opens: .link),
        MenuItem.divider("primary-divider"),
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

    static func block(for ref: Reference) -> Material.Block? {
        switch ref.type {
            case is Artifact.Type: return .artifact(ref)
            case is Command.Type: return .command(ref)
            case is Material.Type: return .material(ref)
            default: return nil
        }
    }

    static func form(for block: Material.Block) -> (MenuFormKind, MenuFormValues)? {
        switch block {
            case .task(_, let text, let completed):
                return (.task, MenuFormValues(primary: text, completed: completed))
            case .artifact(let ref):
                let link = Artifact.with(ref) { artifact -> (Bool, String) in
                    if case .bookmark(let url) = artifact.handler { return (true, url?.absoluteString ?? "") }
                    return (false, "")
                } ?? (false, "")
                return (link.0 ? .link : .artifact, MenuFormValues(primary: link.1, completed: false))
            case .command:
                return (.command, .empty)
            case .material:
                return (.material, .empty)
            case .text:
                return nil
        }
    }

    static func commit(_ outcome: MenuOutcome, editor: ScintEditor) {
        switch outcome.choice {
        case .item(let item):
            if let ref = item.ref {
                if outcome.isInserting, let link = Reference.Link.markdown(for: ref, name: item.label) { editor.replace(outcome.replacementRange, with: link) }
                else if !outcome.isInserting, let replacement = block(for: ref) { editor.replaceCard(outcome.target, with: replacement) }
            } else if let blocks = build(for: item) {
                let links = blocks.compactMap { block -> String? in
                    switch block {
                    case .artifact(let ref), .command(let ref), .material(let ref): Reference.Link.markdown(for: ref)
                    default: nil
                    }
                }
                if !links.isEmpty { editor.replace(outcome.replacementRange, with: links.joined(separator: " ")) }
            }
        case .form(.task, let values):
            let value = values.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = value.isEmpty ? "Task" : value
            if outcome.isInserting { editor.insert(.task(UUID(), text, values.completed), replacing: outcome.replacementRange) }
            else if case .task(let id, _, _)? = editor.card(outcome.target)?.block {
                editor.replaceCard(outcome.target, with: .task(id, text, values.completed))
            }
        case .form(.link, let values):
            guard let url = normalizedURL(from: values.primary.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let ref = Artifact.register(url.host(percentEncoded: false) ?? url.absoluteString, url)
            if outcome.isInserting, let link = Reference.Link.markdown(for: ref) { editor.replace(outcome.replacementRange, with: link) }
            else if !outcome.isInserting { editor.replaceCard(outcome.target, with: .artifact(ref)) }
        case .form(.artifact, _), .form(.command, _), .form(.material, _): break
        }
    }

    private static func referenceType(for form: MenuFormKind) -> (any Any.Type)? {
        switch form {
            case .artifact: return Artifact.self
            case .command: return Command.self
            case .material: return Material.self
            case .task, .link: return nil
        }
    }

    static func build(for item: MenuItem) -> [Material.Block]? {
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
            default: return nil
        }
    }

    private static func normalizedURL(from value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://\(value)")
    }
}
