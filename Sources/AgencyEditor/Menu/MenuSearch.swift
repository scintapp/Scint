import AgencyRuntime
import SwiftUI


enum MenuSearch {
    static func items(for query: String) -> [MenuItem] {
        Runtime.shared.search(query, limit: 12).all.compactMap { result in
            guard entry(for: result.ref) != nil else { return nil }
            return MenuItem.reference(
                result.ref,
                name: result.name,
                description: result.description,
                icon: Design.Component.icon(for: result.ref),
                tags: result.tags.sorted()
            )
        }
    }

    static func entry(for ref: Reference) -> Entry? {
        switch ref.type {
        case is Artifact.Type: return .artifact(ref)
        case is Control.Type: return .control(ref)
        case is Service.Type: return .service(ref)
        case is Sheet.Type: return .sheet(ref)
        default: return nil
        }
    }
}
