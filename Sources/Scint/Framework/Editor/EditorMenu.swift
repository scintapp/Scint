import AppKit
import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


private struct CommandsList: Mapper {
    private static var commands: [SectionParams] {
        [
            SectionParams(id: "insert", layout: .list, items: [
                ItemParams(key: "task", name: "Task", image: "checkmark.app", keywords: ["task", "todo"]),
                ItemParams(key: "link", name: "Link", image: "bookmark", keywords: ["link", "web", "url", "bookmark"])
            ]),
            SectionParams(id: "format", layout: .list, items: [
                ItemParams(key: "title", name: "Title", image: "textformat", value: "# ", keywords: ["h1", "title"]),
                ItemParams(key: "subtitle", name: "Subtitle", image: "textformat.size", value: "## ", keywords: ["h2", "subtitle"]),
                ItemParams(key: "heading", name: "Heading", image: "textformat.size.smaller", value: "### ", keywords: ["h3", "heading"]),
                ItemParams(key: "bulleted-list", name: "Bulleted List", image: "list.bullet", value: "- ", keywords: ["bullet", "list"]),
                ItemParams(key: "numbered-list", name: "Numbered List", image: "list.number", value: "1. ", keywords: ["number", "list"]),
                ItemParams(key: "checklist", name: "Checklist", image: "text.badge.checkmark", value: "- [ ] ", keywords: ["todo", "checkbox"]),
                ItemParams(key: "quote", name: "Quote", image: "quote.opening", value: "> ", keywords: ["blockquote"]),
                ItemParams(key: "code-block", name: "Code Block", image: "curlybraces", value: "```\n", keywords: ["code", "fence"])
            ]),
            SectionParams(id: "add", layout: .list, items: [
                ItemParams(key: "files", name: "Files or Folders...", image: "folder.badge.plus", keywords: ["file", "folder", "directory", "artifact", "open"])
            ])
        ]
    }

    static func controls(_ model: any Model) -> Controls {
        .init(results: { _, query in PanelList.narrowed(commands, by: query) })
    }

    static func parameters(_ model: any Model) -> Params {
        .init(description: "No commands", sections: [.init(id: "commands", header: false, layout: .list)])
    }
}


enum MenuSurface: String, CaseIterable {
    case commands, references, task, link

    var form: Bool { self == .task || self == .link }

    var field: (placeholder: String, image: String, tint: Color, commit: String) {
        switch self {
            case .link: ("URL", "bookmark", Style.Tint.artifact.bright, "Insert Link")
            default: ("Task", "checkmark.app", Style.Tint.task.bright, "Insert Task")
        }
    }
}

@Observable final class EditorMenu: Menu {
    var state: StateContainer = .init()
    var surface: MenuSurface = .commands
    var editor: MarkdownInputView?

    private var range = NSRange(location: 0, length: 0)
    private var anchor: CGRect = .zero

    func controls(_ model: any Model) -> Controls {
        .init(
            onValueChange: { item, query in
                guard item.key == "query", query != self.state.query else { return }
                self.state.query = query
                self.state.index = 0
            },
            onSelect: self.choose,
            onInput: { input in
                PanelNavigation.handle(input, rows: { self.parameters(model).rows(self.state.surface) }, index: self.bindable.index, onSelect: self.choose, onSecondary: nil, onCancel: nil)
            }
        )
    }

    func parameters(_ model: any Model) -> Params {
        let mapped: (params: Params, results: ((SectionParams, String) -> [SectionParams])?) = switch surface {
            case .commands: (CommandsList.parameters(model), CommandsList.controls(model).results)
            case .references: (ReferenceList.parameters(model), ReferenceList.controls(model).results)
            case .task, .link:
                (Params(
                    input: ItemParams(key: "query", name: surface.field.placeholder, image: surface.field.image, tint: surface.field.tint, trailingKind: .field, value: state.query),
                    sections: [.init(id: surface.rawValue, header: false, layout: .list, items: [ItemParams(key: surface.rawValue, name: surface.field.commit, image: "return")])]
                ), nil)
        }
        var params = mapped.params

        params.sections = params.sections.flatMap { mapped.results?($0, state.query) ?? [$0] }
        params.cursor = PanelNavigation.current(params.rows(state.surface), at: state.index)?.id
        params.panel = PanelParams(
            size: CGSize(width: Metrics.menuWidth, height: surface.form ? Metrics.menuFormHeight : Metrics.menuListHeight),
            placement: .anchored(anchor),
            dismissal: surface.form ? [.escape, .resignKey] : [.escape],
            focused: surface.form
        )
        return params
    }

    func open(_ surface: MenuSurface, in editor: MarkdownInputView, query: String, range: NSRange, anchor: CGRect) {
        if self.surface != surface { self.surface = surface; state.index = 0 }
        if state.query != query { state.query = query; state.index = 0 }
        self.editor = editor
        self.range = range
        self.anchor = anchor
    }

    func surface(_ model: PanelModel) -> some Surface { AnySurface(host: self, model: model) }

    private func choose(_ item: ItemParams) {
        guard let editor else { return }
        let text = state.query.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (surface, item.key) {
            case (.commands, "task"), (.commands, "link"):
                surface = item.key == "task" ? .task : .link
                state.query = ""
                state.index = 0
                return editor.presentMenu()

            case (.commands, "files"):
                let panel = NSOpenPanel()
                panel.title = "Add Files or Folders"
                panel.prompt = "Add"
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
                editor.insert(panel.urls.map { .artifact(Artifact.new($0.lastPathComponent.isEmpty ? "Artifact" : $0.lastPathComponent, $0)) }, replacing: range)

            case (.task, _):
                editor.insert([.task(UUID(), text.isEmpty ? "Task" : text, false)], replacing: range)

            case (.link, _):
                guard let url = URL(string: text).flatMap({ $0.scheme == nil ? nil : $0 }) ?? URL(string: "https://\(text)"), !text.isEmpty
                        else { return }
                editor.insert([.artifact(Artifact.new(url.host(percentEncoded: false) ?? url.absoluteString, url))], replacing: range)

            case (.references, _):
                guard let ref = item.ref else { return }
                if let block = Self.block(ref) { editor.insert([block], replacing: range) }
                else { editor.replace(range, with: ScintRuntime.Link.markdown(for: ref, name: item.name) ?? "") }

            default:
                guard let marker = item.value else { return }
                editor.replace(range, with: "")
                editor.replace(NSRange(location: editor.source.lineRange(for: NSRange(location: range.location, length: 0)).location, length: 0), with: marker)
        }

        editor.closeMenu()
        editor.window?.makeFirstResponder(editor)
        self.editor = nil
    }

    private static func block(_ ref: Reference) -> Block? {
        switch ref.type {
            case is Artifact.Type: .artifact(ref)
            case is Command.Type: .command(ref)
            case is ScintRuntime.Document.Type: .document(ref)
            default: nil
        }
    }
}
