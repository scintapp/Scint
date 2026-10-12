import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


struct ContextMenu: View {
    var ref: Reference
    var model: any Model

    var space: Bool { ref.type is Space.Type }
    var document: Bool { ref.type is ScintRuntime.Document.Type }
    var parent: Reference? { Space.with(ref, { $0.space }) ?? nil }
    var origin: Reference? { ReferenceTransfer.origin(of: ref) }
    var items: [ActionParams] { ActionProvider.items(for: ref, in: model) }

    var moveDestinations: [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != ref && $0 != parent && !Navigation().spaces(to: $0).contains(ref) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var spaceDestinations: [Reference] {
        destinations(in: model.session.spaces)
            .filter { destination in
                Space.with(destination, { !$0.documents.contains(ref) }) ?? false
            }
    }

    var folderDestinations: [Reference] {
        ([model.session.library] + destinations(in: model.session.library)).filter { $0 != origin }
    }

    var body: some View {
        ActionMenu(model: model, items: items.filter { $0.role == nil })

        if space {
            SwiftUI.Menu("Move To") {
                if parent != nil {
                    Button("Top Level") {
                        ReferenceTransfer.detach(ref, from: nil)
                    }
                    Divider()
                }
                ForEach(moveDestinations, id: \.self) { destination in
                    Button(destination.descriptor.name) {
                        ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
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
                        }
                    }
                }
            }

            if !folderDestinations.isEmpty {
                SwiftUI.Menu("Move to Folder") {
                    ForEach(folderDestinations, id: \.self) { destination in
                        Button(destination.descriptor.name) {
                            ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                        }
                    }
                }
            }
        }

        Divider()
        ActionMenu(model: model, items: items.filter { $0.role != nil })
    }

    func destinations(in root: Reference) -> [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != root && Navigation().spaces(to: $0).contains(root) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }
}
