import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


struct ContextActionMenu: View {
    let ref: Reference
    let model: any Model

    var space: Bool { ref.type is Space.Type }
    var document: Bool { ref.type is ScintRuntime.Document.Type }
    var folder: Bool { space && Navigation().spaces(to: ref).contains(model.session.library) }
    var parent: Reference? { Space.with(ref, { $0.space }) ?? nil }
    var origin: Reference? { ReferenceTransfer.origin(of: ref) }

    var moveDestinations: [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != ref && $0 != parent && !Navigation().spaces(to: $0).contains(ref) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var spaceDestinations: [Reference] {
        destinations(in: model.session.space)
            .filter { destination in
                Space.with(destination, { !$0.documents.contains(ref) }) ?? false
            }
    }

    var folderDestinations: [Reference] {
        ([model.session.library] + destinations(in: model.session.library)).filter { $0 != origin }
    }

    var body: some View {
        if space {
            Button(folder ? "New Folder…" : "New Space…") {
                prompt(folder ? "New Folder" : "New Space") { name in Space.new(ref, name: name) }
            }
            if folder {
                Button("New Document…") { prompt("New Document") { name in Document.new(ref, name: name) } }
            }
            Divider()
        }

        Button("Rename…") {
            prompt("Rename", ref.descriptor.name) { name in Catalog.shared.update(ref) { $0.name = name } }
        }

        if space {
            SwiftUI.Menu("Move To") {
                if parent != nil {
                    Button("Top Level") {
                        ReferenceTransfer.detach(ref, from: nil)
                        Task { await Runtime.shared.save() }
                    }
                    Divider()
                }
                ForEach(moveDestinations, id: \.self) { destination in
                    Button(destination.descriptor.name) {
                        ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                        Task { await Runtime.shared.save() }
                    }
                }
            }
        }

        if document {
            if !spaceDestinations.isEmpty {
                SwiftUI.Menu("Add to Space") {
                    ForEach(spaceDestinations, id: \.self) { destination in
                        Button(destination.descriptor.name) {
                            ReferenceTransfer.paste([ref], by: nil, move: false, to: destination)
                            Task { await Runtime.shared.save() }
                        }
                    }
                }
            }

            if !folderDestinations.isEmpty {
                SwiftUI.Menu("Move to Folder") {
                    ForEach(folderDestinations, id: \.self) { destination in
                        Button(destination.descriptor.name) {
                            ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                            Task { await Runtime.shared.save() }
                        }
                    }
                }
            }
        }

        Divider()
        Button("Remove", role: .destructive) { Action.remove(ref) }
    }

    private func destinations(in root: Reference) -> [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != root && Navigation().spaces(to: $0).contains(root) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private func prompt(_ title: String, _ initial: String = "", _ apply: @escaping (String) -> Void) {
        let field = NSTextField(string: initial)
        field.placeholderString = "Name"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        alert.beginSheetModal(for: window) { response in
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard response == .alertFirstButtonReturn, !name.isEmpty else { return }
            apply(name)
            Task { await Runtime.shared.save() }
        }
    }
}

