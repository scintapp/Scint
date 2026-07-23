import AgencyRuntime
import AppKit
import SwiftUI



struct Item: Identifiable {
    let id: String
    let label: String
    let image: String
    let role: ButtonRole?
    let enabled: @MainActor (any Model) -> Bool
    let action: @MainActor (any Model) -> Void

    init(id: String, label: String, image: String = "", role: ButtonRole? = nil, enabled: @escaping @MainActor (any Model) -> Bool = { _ in true }, action: @escaping @MainActor (any Model) -> Void) {
        self.id = id
        self.label = label
        self.image = image
        self.role = role
        self.enabled = enabled
        self.action = action
    }
}

@MainActor enum Action {
    private static var clipboard: (refs: [Reference], origin: Reference?, move: Bool)?
    static func create(_ ref: Reference, in model: any Model) {}
    static func open(_ ref: Reference, in model: any Model) {}
    static func start(_ ref: Reference, in model: any Model) {}

    static func rename(_ ref: Reference, in model: any Model) {
        let field = NSTextField(string: ref.descriptor.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Enter a new name."
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            var descriptor = Runtime.shared.get(ref)
            descriptor.name = name
            descriptor.updated = .now
            Runtime.shared.set(ref, descriptor)
            Task { try? await Runtime.shared.save() }
        }
    }

    static func delete(_ ref: Reference, from origin: Reference?, in model: any Model) {
        Task { try? await ref.delete() }
    }

    static func cut(_ ref: Reference, from origin: Reference?, in model: any Model) {
        clipboard = ([ref], origin, true)
    }

    static func copy(_ ref: Reference, from origin: Reference?, in model: any Model) {
        clipboard = ([ref], origin, false)
    }

    static func paste(_ owner: Reference, in model: any Model) {
        guard let payload = clipboard else { return }
        let pasted = ReferenceTransfer.paste(payload.refs, from: payload.origin, move: payload.move, to: owner)
        if let pasted { model.select(pasted) }
        if payload.move { clipboard = nil }
        Task { try? await Runtime.shared.save() }
    }

    static func canPaste(to owner: Reference) -> Bool {
        guard let payload = clipboard else { return false }
        return ReferenceTransfer.canPaste(payload.refs, move: payload.move, to: owner)
    }

    static func createSheet(in owner: Reference, model: any Model) {
        let ref = Sheet.new(owner, name: "New Sheet")
        model.open(ref)
        Task { try? await Runtime.shared.save() }
    }

    static func createSpace(in owner: Reference, model: any Model) {
        let ref = Space.new("New Space", owner: owner)
        model.select(ref)
        Task { try? await Runtime.shared.save() }
    }

    static func surfaceItems(for owner: Reference) -> [Item] {
        [
            .init(id: "new-sheet", label: "New Sheet", image: "text.alignleft") { Action.createSheet(in: owner, model: $0) },
            .init(id: "new-space", label: "New Space", image: "app") { Action.createSpace(in: owner, model: $0) },
            .init(id: "paste", label: "Paste", image: "clipboard", enabled: { _ in Action.canPaste(to: owner) }) { Action.paste(owner, in: $0) }
        ]
    }

    static func itemItems(for item: ItemParams) -> [Item] {
        guard let ref = item.ref else { return [] }
        let origin = item.origin
        var items: [Item] = [
            .init(id: "rename", label: "Rename", image: "pencil") { Action.rename(ref, in: $0) }
        ]
        if canMove(ref, from: origin) {
            items.append(.init(id: "cut", label: "Cut", image: "scissors") { Action.cut(ref, from: origin, in: $0) })
        }
        if ReferenceTransfer.canShare(ref) {
            items.append(.init(id: "copy", label: "Copy", image: "doc.on.doc") { Action.copy(ref, from: origin, in: $0) })
        }
        items.append(.init(id: "delete", label: "Delete", image: "trash", role: .destructive) { Action.delete(ref, from: origin, in: $0) })
        return items
    }

    private static func canMove(_ ref: Reference, from origin: Reference?) -> Bool {
        ref.type is Space.Type || origin != nil
    }
}

struct ActionMenu: View {
    let model: any Model
    let items: [Item]

    var body: some View {
        ForEach(items) { item in
            Button(role: item.role) { item.action(model) } label: {
                if item.image.isEmpty { Text(item.label) }
                else { Label(item.label, systemImage: item.image) }
            }
            .disabled(!item.enabled(model))
        }
    }
}
