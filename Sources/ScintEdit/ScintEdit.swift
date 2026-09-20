import AppKit
import ScintRuntime
import SwiftUI


/// What `/` and `@` offer, and the blocks a choice stamps out. The menu, its panel and
/// the reference search are ScintKit's; this is only the document's side of the wiring.
@MainActor enum EditSurface {
    static let items: [MenuItem] = [
        .command(id: "new-task", label: "Task", icon: "checkmark.circle", keywords: ["task", "todo"], opens: .task),
        .command(id: "new-link", label: "Link", icon: "link", keywords: ["link", "web", "url"], opens: .link),
        .divider("blocks"),
        .command(id: "heading-1", label: "Heading 1", icon: "textformat.size", keywords: ["h1", "title"]),
        .command(id: "heading-2", label: "Heading 2", icon: "textformat.size.smaller", keywords: ["h2", "subtitle"]),
        .command(id: "heading-3", label: "Heading 3", icon: "textformat", keywords: ["h3"]),
        .command(id: "bulleted-list", label: "Bulleted List", icon: "list.bullet", keywords: ["bullet", "list"]),
        .command(id: "numbered-list", label: "Numbered List", icon: "list.number", keywords: ["number", "list"]),
        .command(id: "checklist", label: "Checklist", icon: "checklist", keywords: ["todo", "checkbox"]),
        .command(id: "quote", label: "Quote", icon: "quote.opening", keywords: ["blockquote"]),
        .command(id: "code-block", label: "Code Block", icon: "curlybraces", keywords: ["code", "fence"]),
        .divider("files"),
        .command(id: "add-files", label: "Files or Folders...", icon: "folder.badge.plus", keywords: ["file", "folder", "directory", "artifact", "open"])
    ]

    /// `@` searches the catalog, narrowed to what a document can hold as a block.
    static func search(_ query: String, kind: MenuKind) -> [MenuItem] {
        guard case .dynamic = kind else { return [] }
        return SearchMenu.search(for: query) { block(for: $0) != nil }
    }

    static func blocks(for outcome: MenuOutcome) -> [Document.Block] {
        switch outcome.choice {
            case .item(let item):
                if let ref = item.ref { return block(for: ref).map { [$0] } ?? [] }
                return item.commandID.map { stamp($0) } ?? []

            case .form(.task, let values):
                let title = values.primary.trimmingCharacters(in: .whitespacesAndNewlines)
                return [.task(UUID(), title.isEmpty ? "Task" : title, values.completed)]

            case .form(.link, let values):
                // Artifact.handler is immutable and classified from the URL, so a link
                // without a resolvable one can't become an artifact.
                guard let url = url(from: values.primary) else { return [] }
                return [.artifact(Artifact.new(url.host(percentEncoded: false) ?? url.absoluteString, url))]

            case .form:
                return []
        }
    }

    nonisolated static func block(for ref: Reference) -> Document.Block? {
        switch ref.type {
            case is Artifact.Type: return .artifact(ref)
            case is Command.Type: return .command(ref)
            case is Document.Type: return .document(ref)
            default: return nil
        }
    }

    /// Markdown prefixes are text, so they splice into the block the trigger came from.
    private static func stamp(_ command: String) -> [Document.Block] {
        switch command {
            case "heading-1": return [.text(UUID(), "# ")]
            case "heading-2": return [.text(UUID(), "## ")]
            case "heading-3": return [.text(UUID(), "### ")]
            case "bulleted-list": return [.text(UUID(), "- ")]
            case "numbered-list": return [.text(UUID(), "1. ")]
            case "checklist": return [.text(UUID(), "- [ ] ")]
            case "quote": return [.text(UUID(), "> ")]
            case "code-block": return [.text(UUID(), "```\n\n```")]
            case "add-files": return files()
            default: return []
        }
    }

    private static func files() -> [Document.Block] {
        let panel = NSOpenPanel()
        panel.title = "Add Files or Folders"
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.map { url in
            .artifact(Artifact.new(url.lastPathComponent.isEmpty ? "Artifact" : url.lastPathComponent, url))
        }
    }

    private nonisolated static func url(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }
}


struct ScintEdit: View {
    @State private var model: EditModel
    private let onFocus: () -> Void

    init(ref: Reference, onFocus: @escaping () -> Void = {}) {
        self.onFocus = onFocus
        _model = State(initialValue: EditModel(document: ref))
    }

    var body: some View {
        EditCanvas()
            .environment(model)
            .onAppear {
                model.onFocus = onFocus
                model.prepare()
            }
    }
}
