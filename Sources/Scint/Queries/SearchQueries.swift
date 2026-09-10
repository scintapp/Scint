import SwiftUI


struct ContentSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                let found = model.search(input, limit: 200).all

                return [
                    .init(
                        id: "materials",
                        results: Array(found.filter { $0.ref.type is Material.Type }.prefix(50))
                    )
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
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
        .init(nesting: .recursive, header: false)
    }
}

struct InterfaceSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                let found = model.search(input, limit: 200).all

                return [
                    .init(id: "artifacts", name: "Artifacts", results: found.filter { $0.ref.type is Artifact.Type }),
                    .init(id: "commands", name: "Commands", results: found.filter { $0.ref.type is Command.Type }),
                    .init(id: "harnesses", name: "Harnesses", results: found.filter { $0.ref.type is Harness.Type }),
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
        .init(nesting: .flat)
    }
}

struct WorkspaceSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                let found = model.search(input, limit: 200).all
                let spaces = found.filter { $0.ref.type is Space.Type }
                let edges = found.filter { $0.ref.type is Bridge.Type }
                let workspace = found.filter { $0.ref == model.session.workspace }

                return [
                    .init(
                        id: "spaces",
                        results: Array((spaces + edges + workspace).prefix(50))
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
            nesting: .flat
        )
    }
}

struct EverythingSearch: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            results: { input in
                let found = model.search(input, limit: 200).all
                let limit = 50 / 3

                let content = found.filter { $0.ref.type is Material.Type }
                let interfaces = found.filter { $0.ref.type is any Functional.Type }
                let spaces = found.filter { $0.ref.type is Space.Type || $0.ref.type is Bridge.Type }
                let workspace = found.filter { $0.ref == model.session.workspace }

                return [
                    .init(id: "content", name: "Content", image: "text.alignleft", results: Array(content.prefix(limit))),
                    .init(id: "interfaces", name: "Interfaces", image: "switch.2", results: Array(interfaces.prefix(limit))),
                    .init(id: "workspace", name: "Workspace", image: "cube.transparent", results: Array((spaces + workspace).prefix(limit))),
                ]
            },
            detail: { SearchDetail.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any Malleable.Type { model.open(ref) }
                else { model.select(ref) }
            },
            onAction: { SearchDetail.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(nesting: .flat)
    }
}
