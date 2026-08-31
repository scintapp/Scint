import Foundation


/// Turns a query into reference items.
///
/// It has no opinion about which references are usable — that is the host's call, made through
/// `matching`. It used to additionally require that a reference could become a `Material.Block`,
/// which quietly made the search an editor component.
enum MenuSearch {
    static func items(
        for query: String,
        limit: Int = 60,
        take: Int = 12,
        matching: (Reference) -> Bool = { _ in true }
    ) -> [MenuItem] {
        Runtime.shared.search(query, limit: limit).all.compactMap { result in
            guard matching(result.ref) else { return nil }
            return MenuItem.reference(
                result.ref,
                name: result.name,
                description: result.description,
                tags: result.tags.sorted()
            )
        }
        .prefix(take)
        .map { $0 }
    }
}
