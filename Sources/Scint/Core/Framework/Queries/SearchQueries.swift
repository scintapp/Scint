import SwiftUI
import ScintRuntime
import ScintComponents


struct ContentSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                [
                    .init(
                        id: "documents",
                        results: model.search(input, filters: ["document"], limit: 50).all
                    )
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.open(ref)
            },
            onAction: { SearchDetail.perform($0, model) },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(header: false)
    }
}

struct InterfaceSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                [
                    .init(id: "artifacts", name: "Artifacts", results: model.search(input, filters: ["artifact"], limit: 50).all),
                    .init(id: "commands", name: "Commands", results: model.search(input, filters: ["command"], limit: 50).all),
                    .init(id: "harnesses", name: "Harnesses", results: model.search(input, filters: ["harness"], limit: 50).all),
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            onAction: { SearchDetail.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct WorkspaceSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                [
                    .init(
                        id: "spaces",
                        results: model.search(input, filters: ["structure"], limit: 50).all
                    )
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            onAction: { SearchDetail.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
        )
    }
}

struct EverythingSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                let limit = 50 / 3

                return [
                    .init(id: "content", name: "Content", image: "text.alignleft", results: model.search(input, filters: ["document"], limit: limit).all),
                    .init(id: "interfaces", name: "Interfaces", image: "switch.2", results: model.search(input, filters: ["interface"], limit: limit).all),
                    .init(id: "space", name: "Workspace", image: "cube.transparent", results: model.search(input, filters: ["structure"], limit: limit).all),
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any ScintRuntime.Material.Type { model.open(ref) }
                else { model.select(ref) }
            },
            onAction: { SearchDetail.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

