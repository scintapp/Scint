import SwiftUI
import AgencyRuntime


struct SheetsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        func selected(_ item: ItemParams) -> Bool {
            guard let ref = item.ref else { return false }
            if let url = item.path { return agency.session.selected.selected(ref, url) }
            return agency.session.selected.selected(ref)
        }

        func select(_ item: ItemParams) {
            guard let ref = item.ref else { return }
            if ref.type is Sheet.Type {
                agency.select(ref)
                agency.open(ref)
                return
            }
            agency.select(ref)
        }

        return Controls(
            selected: selected,
            onSelect: select,
            itemActions: { item in item.path == nil ? Action.itemItems(for: item) : [] },
            wrapLink: { view, item, depth in
                guard depth == 0, let ref = item.ref, ref.type is Sheet.Type else { return view }
                return AnyView(
                    CardLink(
                        ref: ref,
                        title: item.name,
                        selected: selected(item),
                        onSelect: { select(item) }
                    )
                )
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let owner = agency.session.selected.space ?? agency.session.workspace
        let closure = Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.state }) } ?? []

        func items(image: String) -> [ItemParams] {
            sortItems(sheets.compactMap { ref in
                guard ref.type is Sheet.Type else { return nil }
                return .init(
                    ref: ref,
                    origin: owner,
                    name: ref.descriptor.name,
                    image: image
                )
            })
        }

        return .init(
            nesting: .recursive,
            header: false,
            sections: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: false,
                    items: items(image: "text.alignleft")
                ),
            ],
        )
    }
}
