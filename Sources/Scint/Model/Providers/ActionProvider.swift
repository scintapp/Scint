import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct ActionProvider {
    @MainActor enum ReferenceAction {
        @discardableResult
        static func open(_ ref: Reference) -> Bool {
            if let url = Artifact.with(ref, { $0.handle.url }) ?? nil { return open(url) }
            return true
        }

        private static func open(_ url: URL) -> Bool {
            guard url.isFileURL else { return NSWorkspace.shared.open(url) }
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists else { return false }
            if isDirectory.boolValue, url.pathExtension.lowercased() != "app" { NSWorkspace.shared.open(url) }
            else { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            return true
        }
    }

    static func sections(_ model: any Model) -> [(name: String, items: [ActionParams])] {
        let target = model.session.focus.ref
        return [
            (name: target?.descriptor.name ?? "", items: target.map(operations) ?? []),
            (name: "New", items: new(model)),
            (name: "Go", items: go),
            (name: "View", items: view(model))
        ]
            .filter { !$0.items.isEmpty }
    }

    static func items(for ref: Reference, in model: any Model) -> [ActionParams] {
        creation(in: ref, model) + operations(on: ref)
    }

    static func operations(on ref: Reference) -> [ActionParams] {
        let items: [ActionParams?] = [
            ref.type is any ScintRuntime.Material.Type ?
            ActionParams(id: "open", label: "Open", image: "arrow.up.forward.square", keywords: ["show", "view", "launch"]) { $0.open(ref) } :
                ActionParams(id: "compose", label: "Compose", image: "play", keywords: ["run", "start", "execute", "play"]) { $0.compose(ref) },
            ActionParams(id: "cancel", label: "Cancel", image: "stop", keywords: ["stop", "halt", "abort"]) { $0.cancel(ref) },
            ActionParams(id: "rename", label: "Rename…", image: "pencil", keywords: ["name", "title", "edit"]) { _ in rename(ref) },
            ActionParams(id: "copy-link", label: "Copy Link", image: "link", keywords: ["url", "share", "clipboard"]) { _ in copy(ref.url?.absoluteString) },
            ActionParams(id: "copy-markdown", label: "Copy Markdown Link", image: "text.badge.plus", keywords: ["url", "share", "clipboard", "md"]) { _ in copy(ScintRuntime.Link.markdown(for: ref)) },
            ActionParams(id: "remove", label: "Remove", image: "trash", keywords: ["delete", "trash", "discard"], role: .destructive) { _ in remove(ref) }
        ]
        return items.compactMap { $0 }
    }

    static func creation(in ref: Reference, _ model: any Model) -> [ActionParams] {
        guard ref.type is Space.Type else { return [] }
        let folder = Navigation().spaces(to: ref).contains(model.session.library)
        let items: [ActionParams?] = [
            ActionParams(id: "new-space", label: folder ? "New Folder…" : "New Space…", image: "folder.badge.plus", keywords: ["create"]) { _ in newSpace(in: ref, named: folder ? "New Folder" : "New Space", intent: folder ? .none : .compose) },
            folder ? ActionParams(id: "new-document", label: "New Document…", image: "doc.badge.plus", keywords: ["create"]) { _ in newDocument(in: ref) } : nil
        ]
        return items.compactMap { $0 }
    }

    static func new(_ model: any Model) -> [ActionParams] {
        let session = model.session
        let space = session.focus.ref.flatMap { $0.type is Space.Type ? $0 : nil }
        let within = { (root: Reference) in space.flatMap { $0 == root || Navigation().spaces(to: $0).contains(root) ? $0 : nil } ?? root }
        let folder = within(session.library), project = within(session.spaces)
        return [
            ActionParams(id: "new-document", label: "New Document", image: "doc.badge.plus", keywords: ["create", "doc", "note", "page", "write"]) { $0.open(ScintRuntime.Document.new(.init(name: "New Document", origin: folder))) },
            ActionParams(id: "new-task", label: "New Task", image: "checkmark.app", keywords: ["create", "todo", "reminder"]) {
                $0.open(Document.new(.init(name: "New Task", origin: $0.session.agenda)))
            },
            ActionParams(id: "new-folder", label: "New Folder…", image: "folder.badge.plus", keywords: ["create", "directory", "group"]) { _ in newSpace(in: folder, named: "New Folder", intent: .none) },
            ActionParams(id: "new-project", label: "New Space…", image: "square.stack.3d.up", keywords: ["create", "space", "workspace"]) { _ in newSpace(in: project, named: "New Space", intent: .compose) }
        ]
    }

    static let go: [ActionParams] = [
        ActionParams(id: "back", label: "Back", image: "chevron.backward", keywords: ["previous", "history", "return"], enabled: { $0.session.navigation.canGoBack }) { $0.session.back() },
        ActionParams(id: "forward", label: "Forward", image: "chevron.forward", keywords: ["next", "history"], enabled: { $0.session.navigation.canGoForward }) { $0.session.forward() },
        //        ActionParams(id: "inbox", label: "Inbox", image: "tray", keywords: ["open", "show", "messages"]) { $0.select($0.session.inbox) },
        ActionParams(id: "library", label: "Library", image: "books.vertical", keywords: ["open", "show", "documents", "folders"]) { $0.select($0.session.library) },
        ActionParams(id: "spaces", label: "Spaces", image: "app", keywords: ["open", "show", "spaces", "workspaces"]) { $0.select($0.session.spaces) },
        ActionParams(id: "tasks", label: "Tasks", image: "checklist", keywords: ["open", "show", "todos", "reminders"]) { $0.select($0.session.agenda) }
    ]

    static func view(_ model: any Model) -> [ActionParams] {
        guard let app = model as? AppModel else { return [] }
        let inspector = app.inspector
        return InspectorFrame.HostSurface.allCases.map { surface in
            ActionParams(id: surface.rawValue, label: "Show \(surface.label)", image: surface.symbol, keywords: ["inspector", "sidebar", "panel"]) { _ in
                inspector.surface = surface
                inspector.state.presented = true
            }
        } + [
            ActionParams(id: "inspector", label: inspector.state.presented ? "Hide Inspector" : "Show Inspector", image: "sidebar.trailing", keywords: ["sidebar", "panel", "toggle"]) { _ in
                inspector.state.presented.toggle()
            }
        ]
    }

    static func rename(_ ref: Reference) {
        prompt("Rename", ref.descriptor.name) { name in Catalog.shared.update(ref) { $0.name = name } }
    }

    static func newSpace(in origin: Reference, named name: String, intent: Intent) {
        prompt(name) { name in Space.new(.init(name: name, origin: origin, intent: intent)) }
    }

    static func newDocument(in origin: Reference) {
        prompt("New Document") { name in ScintRuntime.Document.new(.init(name: "Input", origin: origin)) }
    }

    static func remove(_ ref: Reference) {
        Task { await Runtime.shared.remove(ref) }
    }

    static func copy(_ text: String?) {
        guard let text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func prompt(_ title: String, _ initial: String = "", _ apply: @escaping (String) -> Void) {
        let field = NSTextField(string: initial)
        field.placeholderString = "Name"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else { return }
        alert.beginSheetModal(for: window) { response in
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard response == .alertFirstButtonReturn, !name.isEmpty else { return }
            apply(name)
        }
    }
}
