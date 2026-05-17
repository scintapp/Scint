import AgencyRuntime
import SwiftUI


struct EditorLibrarySection: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let items: [EditorLibraryItem]
}

struct EditorLibraryItem: Identifiable, Equatable {
    var id: Reference { ref }
    let ref: Reference
    let name: String
    let description: String
    let icon: String
    let tags: [String]
}

enum EditorLibrarySearch {
    static func sections(for query: String) -> [EditorLibrarySection] {
        [
            section(
                id: "sheets",
                title: "Sheets",
                icon: "doc.text",
                results: Runtime.shared.search("\(query) !sheet", limit: 24).all,
                include: { $0.ref.type is Sheet.Type }
            ),
            section(
                id: "artifacts",
                title: "Artifacts",
                icon: "archivebox",
                results: Runtime.shared.search(query, limit: 40).all,
                include: { $0.ref.type is Artifact.Type }
            ),
            section(
                id: "controls",
                title: "Controls",
                icon: "switch.2",
                results: Runtime.shared.search("\(query) !control", limit: 24).all,
                include: { $0.ref.type is Control.Type }
            ),
            section(
                id: "services",
                title: "Services",
                icon: "app.connected.to.app.below.fill",
                results: Runtime.shared.search("\(query) !service", limit: 24).all,
                include: { $0.ref.type is Service.Type }
            )
        ]
        .compactMap { $0 }
    }

    static func entry(for ref: Reference) -> Entry? {
        switch ref.type {
        case is Artifact.Type: return .artifact(ref)
        case is Control.Type: return .control(ref)
        case is Service.Type: return .service(ref)
        case is Sheet.Type: return .sheet(ref)
        default:
            return nil
        }
    }

    private static func section(id: String, title: String, icon: String, results: [SearchResult],
                                include: (SearchResult) -> Bool) -> EditorLibrarySection? {

        let items = results
            .filter(include)
            .map { result in
                EditorLibraryItem(
                    ref: result.ref,
                    name: result.name,
                    description: result.description,
                    icon: Design.Component.icon(for: result.ref),
                    tags: result.tags.sorted()
                )
            }

        guard !items.isEmpty else { return nil }
        return EditorLibrarySection(id: id, title: title, icon: icon, items: items)
    }
}
