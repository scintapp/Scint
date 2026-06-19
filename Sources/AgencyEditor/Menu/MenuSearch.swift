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
                tags: result.tags.sorted()
            )
        }
    }

    static func entry(for ref: Reference) -> Block? {
        switch ref.type {
        case is Artifact.Type: return .artifact(ref)
        case is Command.Type: return .command(ref)
        case is Sheet.Type: return .sheet(ref)
        default: return nil
        }
    }
}
