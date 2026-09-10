import Foundation


struct Search: Codable, Sendable, Hashable {
    let text: String
    let input: String
    let filters: [String]

    enum Query {
        static func token(_ value: String) -> String { value.normalized.replacingOccurrences(of: " ", with: "") }

        static func describing(_ ref: Reference) -> String { ref.type.map { String(describing: $0) } ?? "Unknown" }

        static func facets(for type: Resolvable.Type?) -> Set<String> {
            guard let type else { return [] }
            var facets: Set<String> = []
            if type is any Structural.Type { facets.formUnion(["structural", "structure"])}
            if type is any Malleable.Type { facets.formUnion(["composable", "component"]) }
            if type is any Functional.Type { facets.formUnion(["interfacing", "interface"]) }
            if type is any Contextual.Type { facets.formUnion(["contextual", "context"]) }
            return facets
        }

        static func keys(for ref: Reference, tags: Set<String>) -> Set<String> {
            let typeDescription = describing(ref)
            let typeToken = token(typeDescription)
            var values = Set([typeToken])
            values.formUnion(facets(for: ref.type))
            values.formUnion(tags.map(token).filter { !$0.isEmpty })
            if let initial = typeToken.first { values.insert(String(initial)) }
            return values.filter { !$0.isEmpty }
        }

        static func matches(_ filter: String, ref: Reference, tags: Set<String>) -> Bool {
            let filter = token(filter)
            guard !filter.isEmpty else { return true }
            let keys = keys(for: ref, tags: tags)
            if filter.count == 1 { return keys.contains(filter) }
            return keys.contains(filter) || keys.contains { $0.hasPrefix(filter) }
        }

        static func rank(_ results: [SearchResult], limit: Int) -> [SearchResult] {
            guard limit > 0 else { return [] }
            return results
                .sorted { if $0.score == $1.score { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    return $0.score > $1.score
                }
                .prefix(limit)
                .map { $0 }
        }
    }

    init(_ input: String) {
        var terms: [String] = []
        var filters: [String] = []

        for token in input.split(whereSeparator: \.isWhitespace).map(String.init) {
            if token.hasPrefix("!"), token.count > 1 { filters.append(String(token.dropFirst())) }
            else { terms.append(token) }
        }

        self.input = input
        self.text = terms.joined(separator: " ")
        self.filters = filters
            .map(Query.token)
            .filter { !$0.isEmpty }
    }
}

struct SearchResult: Codable, Sendable, Identifiable {
    var id: UUID { ref.id }
    let ref: Reference
    let name: String
    let description: String
    let tags: Set<String>
    let score: Double

    init(ref: Reference, name: String, description: String, tags: Set<String>, score: Double) {
        self.ref = ref
        self.name = name
        self.description = description
        self.tags = tags
        self.score = score
    }

    init?(descriptor: Descriptor, search: Search) {
        guard descriptor.published else { return nil }
        guard search.filters
            .allSatisfy({ Search.Query.matches($0, ref: descriptor.origin, tags: descriptor.tags) }) else {
            return nil
        }
        let score = Self.score(descriptor, query: search.text)
        guard score > 0 else { return nil }
        self.init(descriptor: descriptor, score: score)
    }

    init(descriptor: Descriptor, score: Double) {
        self.ref = descriptor.origin
        self.name = descriptor.name
        self.description = descriptor.description
        self.tags = descriptor.tags
        self.score = score
    }

    static func score(_ descriptor: Descriptor, query: String) -> Double {
        let needle = query.normalized
        let tokens = query.tokenized
        guard !needle.isEmpty else { return 1 }

        let name = descriptor.name.normalized
        let description = descriptor.description.normalized
        let tags = descriptor.tags.map(\.normalized)
        let typeTerms = Array(Search.Query.keys(for: descriptor.origin, tags: descriptor.tags))
        let searchable = ([name, description] + tags + typeTerms).joined(separator: " ")

        guard tokens.allSatisfy({ searchable.contains($0) }) else { return 0 }

        if name == needle { return 100 }
        if name.hasPrefix(needle) { return 85 }
        if name.contains(needle) { return 70 }
        if tags.contains(needle) { return 60 }
        if typeTerms.contains(Search.Query.token(needle)) { return 50 }
        if description.contains(needle) { return 40 }
        if tags.contains(where: { $0.contains(needle) }) { return 30 }
        if tokens.allSatisfy({ name.contains($0) }) { return 25 }
        if tokens.allSatisfy({ tags.joined(separator: " ").contains($0) }) { return 20 }
        if tokens.allSatisfy({ description.contains($0) }) { return 10 }
        return 0
    }
}

struct SearchResults: Codable, Sendable {
    let query: String
    let filters: [String]
    let all: [SearchResult]

    init(query: String, filters: [String] = [], all: [SearchResult]) {
        self.query = query
        self.filters = filters
        self.all = all
    }
}

extension String {
    var normalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .map { $0.isLetter || $0.isNumber ? String($0).lowercased() : " " }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    var tokenized: [String] {
        normalized
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
