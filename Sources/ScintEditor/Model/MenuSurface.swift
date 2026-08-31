import AppKit
import SwiftUI


/// The editor's half of the menu.
///
/// `MenuController` decides what the reader picked; this decides what that means in a `Material`.
/// Everything here is knowledge the menu used to hold and shouldn't have: which items exist, which
/// references can become blocks, and how an outcome turns into a mutation.
@MainActor enum MenuSurface {
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

    /// Resolves a query for the kinds that are backed by references. Form kinds return nothing,
    /// which is how the controller learns they are forms rather than lists.
    static func search(_ query: String, kind: MenuKind) -> [MenuItem] {
        switch kind {
            case .dynamic:
                return MenuSearch.items(for: query) { ReferenceURL.url(for: $0) != nil }
            case .update(let form):
                guard let type = referenceType(for: form) else { return [] }
                return MenuSearch.items(for: query) { $0.type == type }
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

    /// The form that edits an existing block, prefilled.
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

    /// Applies a committed choice to the document.
    ///
    /// Returns the block the caret should land on and, when the insertion stayed inside one text
    /// block, where in it.
    static func apply(
        _ outcome: MenuOutcome,
        to material: DocumentModel
    ) -> (id: AnyHashable, caret: NSRange?)? {
        guard let blocks = blocks(for: outcome, in: material) else { return nil }

        guard outcome.isInserting else {
            guard let block = blocks.first,
                  let id = material.update(block, replacing: outcome.target)
            else { return nil }
            return (id, nil)
        }

        return material.insert(blocks, replacing: outcome.replacementRange, in: outcome.target)
    }

    /// A reference always lands inline, whichever menu produced it.
    ///
    /// `/` creates the object and `@` finds one that already exists, but what reaches the document
    /// is the same thing either way: a markdown link. A reference used to arrive from `/` as a
    /// block of its own — a full-width row wrapped around a single chip, taking a line to say what
    /// a few characters could, and a second representation of something that already had one.
    ///
    /// `DocumentModel.insert` splices an all-text insertion into the block at the replacement
    /// range, so this needs no separate path.
    private static func inlined(_ blocks: [Material.Block]) -> [Material.Block]? {
        let pieces = blocks.compactMap { block -> String? in
            switch block {
                case .artifact(let ref), .command(let ref), .material(let ref):
                    return ReferenceURL.markdown(for: ref)
                case .text(_, let value):
                    return value
                case .task:
                    return nil
            }
        }

        // A task is a real block; anything holding one stays as it is.
        guard pieces.count == blocks.count else { return blocks }
        guard !pieces.isEmpty else { return nil }
        return [.text(UUID(), pieces.joined(separator: " "))]
    }

    private static func blocks(for outcome: MenuOutcome, in material: DocumentModel) -> [Material.Block]? {
        switch outcome.choice {
            case .item(let item):
                if let ref = item.ref {
                    guard let link = ReferenceURL.markdown(for: ref, name: item.label) else { return nil }
                    return [.text(UUID(), link)]
                }
                guard let built = build(for: item), !built.isEmpty else { return nil }
                return inlined(built)

            case .form(.task, let values):
                let text = values.primary.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = if case .task(let existing, _, _)? = material.block(id: outcome.target), !outcome.isInserting {
                    existing
                } else {
                    UUID()
                }
                return [.task(id, text.isEmpty ? "Task" : text, values.completed)]

            case .form(.link, let values):
                guard let url = normalizedURL(from: values.primary.trimmingCharacters(in: .whitespacesAndNewlines))
                else { return nil }
                let name = url.host(percentEncoded: false) ?? url.absoluteString
                return inlined([.artifact(Artifact.register(name, url))])

            case .form(.artifact, _), .form(.command, _), .form(.material, _):
                return nil
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

    private static func normalizedURL(from value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://\(value)")
    }
}
