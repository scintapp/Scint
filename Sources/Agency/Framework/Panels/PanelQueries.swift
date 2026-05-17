import SwiftUI
import AgencyRuntime


func search(_ query: String, facet: String, limit: Int) -> [ItemParams] {
    Runtime.shared
        .search("\(query) !\(facet)", limit: limit)
        .all
        .map(item(from:))
}

func item(from result: SearchResult) -> ItemParams {
    ItemParams(
        ref: result.ref,
        name: result.name,
        image: Design.Component.icon(for: result.ref),
        description: result.description,
        tags: result.tags.sorted()
    )
}

struct PanelSearchQueries {
    @MainActor
    static func params(_ agency: AgencyModel) -> Params {
        let query = agency.search.query

        return Params(
            nesting: .flat,
            sections: [
                section(
                    id: "space",
                    name: "Space",
                    image: "cube.transparent",
                    items: search(query, facet: "structural", limit: 50)
                ),
                section(
                    id: "sheets",
                    name: "Sheets",
                    image: "text.alignleft",
                    items: search(query, facet: "sheet", limit: 50)
                ),
                section(
                    id: "interfaces",
                    name: "Interfaces",
                    image: "switch.2",
                    items: search(query, facet: "interfacing", limit: 50)
                ),
                section(
                    id: "processes",
                    name: "Processes",
                    image: "arrow.2.squarepath",
                    items: search(query, facet: "service", limit: 50)
                )
            ].compactMap { $0 }
        )
    }

    private static func section(id: String, name: String, image: String, items: [ItemParams]) -> ListParams? {
        guard !items.isEmpty else { return nil }
        return ListParams(id: id, name: name, image: image, layout: .list, items: items)
    }
}
