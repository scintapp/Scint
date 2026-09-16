import UniformTypeIdentifiers
import Foundation
import SwiftUI


struct ContextActionMenu: View {
    let ref: Reference

    var space: Bool { ref.type is Space.Type }
    var parent: Reference? { Space.with(ref, { $0.space }) ?? nil }

    var destinations: [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != ref && $0 != parent && !Navigation().spaces(to: $0).contains(ref) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var body: some View {
        if space {
            Button("New Space…") { prompt("New Space") { name in Space.new(ref, name: name) } }
            Button("New Material…") { prompt("New Material") { name in Material.new(ref, name: name) } }
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
                ForEach(destinations, id: \.self) { destination in
                    Button(destination.descriptor.name) {
                        ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                        Task { await Runtime.shared.save() }
                    }
                }
            }
        }

        Divider()
        Button("Delete", role: .destructive) { Action.delete(ref) }
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




