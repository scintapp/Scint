import AgencyRuntime


enum MenuSearch {
    static func items(for query: String, matching: (Reference) -> Bool = { _ in true }) -> [MenuItem] {
        Runtime.shared.search(query, limit: 60).all.compactMap { result in
            guard matching(result.ref), block(for: result.ref) != nil else { return nil }
            return MenuItem.reference(
                result.ref,
                name: result.name,
                description: result.description,
                tags: result.tags.sorted()
            )
        }.prefix(12).map { $0 }
    }

    static func block(for ref: Reference) -> Sheet.Block? {
        switch ref.type {
        case is Artifact.Type: return .artifact(ref)
        case is Command.Type: return .command(ref)
        case is Sheet.Type: return .sheet(ref)
        default: return nil
        }
    }
}
