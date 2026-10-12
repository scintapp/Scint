import SwiftUI
import ScintRuntime
import ScintComponents


struct PanelList {
    static func narrowed(_ items: [ItemParams], by query: String) -> [ItemParams] {
        items.enumerated()
            .compactMap { place, item -> (item: ItemParams, place: Int, score: Double)? in
                guard item.isParent else {
                    let score = Search.score(query, name: item.name, description: item.description, terms: item.keywords)
                    return score > 0 ? (item, place, score) : nil
                }
                let children = narrowed(item.items, by: query)
                guard let best = children.first else { return nil }
                let score = Search.score(query, name: best.name, description: best.description, terms: best.keywords)
                return (ItemParams(key: item.key, name: item.name, image: item.image, items: children, isParent: true), place, score)
            }
            .sorted { $0.score == $1.score ? $0.place < $1.place : $0.score > $1.score }
            .map(\.item)
    }
}

struct ReferenceList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(results: { section, query in
            model.search(query, filters: [section.id.base as? String ?? ""], limit: 24).all.map {
                ItemParams(ref: $0.ref, name: $0.ref.descriptor.name, description: $0.ref.descriptor.description)
            }
        })
    }

    static func parameters(_ model: any Model) -> Params {
        .init(description: "No references", sections: [.init(id: "", header: false, layout: .list)])
    }
}

struct ReferenceDetail: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let app: Model = (model as? PanelModel)?.app ?? model
        return .init(onSelect: { item in
            guard let ref = model.session.focus.ref else { return }
            ActionProvider.items(for: ref, in: app).first { $0.id == item.key }?.action(app)
        })
    }

    static func parameters(_ model: any Model) -> Params {
        guard let ref = model.session.focus.ref else { return .init() }
        let app: Model = (model as? PanelModel)?.app ?? model
        let about = [
            (name: "Kind", value: ref.type.map { "\($0)" } ?? "Unknown"),
            (name: "Updated", value: ref.descriptor.updated.formatted(date: .abbreviated, time: .shortened)),
            (name: "Tags", value: ref.descriptor.tags.sorted().joined(separator: ", "))
        ]
        .filter { !$0.value.isEmpty }
        .map { ItemParams(key: $0.name.lowercased(), name: $0.name, description: $0.value) }

        return .init(
            ref: ref,
            header: true,
            sections: [
                .init(id: "about", name: "About", layout: .group, items: about),
                .init(id: "actions", name: "Actions", layout: .list, items: ActionProvider.items(for: ref, in: app).map { ItemParams(key: $0.id, name: $0.label, image: $0.image) })
            ]
        )
    }
}

struct ActionsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let app: Model = (model as? PanelModel)?.app ?? model
        let sections = ActionProvider.sections(app)

        return .init(
            onSelect: { item in sections.first { $0.name == item.key }?.items.first { $0.id == item.value }?.action(app) },
            results: { _, query in
                PanelList.narrowed(sections.map { section in
                    ItemParams(key: section.name, name: section.name, items: section.items.filter { $0.enabled(app) }.map {
                        ItemParams(key: section.name, name: $0.label, image: $0.image, value: $0.id, keywords: $0.keywords + [section.name])
                    }, isParent: true)
                }, by: query)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(description: "No matches", sections: [
            .init(id: "actions", header: false, layout: .list, items: [ItemParams(key: "query", name: "Actions", image: "command", trailingKind: .field)])
        ])
    }
}

struct SearchList: Mapper {
    enum Tab: String, CaseIterable {
        case everything, content, interfaces, projects

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .projects: "cube.transparent"
            }
        }

        var groups: [(name: String, filter: String)] {
            switch self {
                case .everything: [("Content", "document"), ("Interfaces", "interface"), ("Workspace", "structure")]
                case .content: [("", "document")]
                case .interfaces: [("Artifacts", "artifact"), ("Commands", "command"), ("Harnesses", "harness")]
                case .projects: [("", "structure")]
            }
        }
    }

    static func controls(_ model: any Model) -> Controls {
        let app: Model = (model as? PanelModel)?.app ?? model
        let references = ReferenceList.controls(model)

        return .init(
            selected: { item in item.ref.map { model.session.selection.selected($0) } ?? false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any ScintRuntime.Material.Type { app.open(ref) }
                else { app.select(ref) }
            },
            onAction: { item in if let ref = item.ref { model.focus(ref) } },
            results: { tab, query in
                (Tab(rawValue: tab.id.base as? String ?? "") ?? .everything).groups
                    .map { ItemParams(key: $0.filter, name: $0.name, items: references.results?(.init(id: $0.filter), query) ?? [], isParent: true) }
                    .filter { !$0.items.isEmpty }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(description: "No matches", tabbed: true, sections: Tab.allCases.map { tab in
            .init(id: tab.rawValue, name: tab.rawValue.capitalized, header: false, image: tab.image, layout: .list, items: [
                ItemParams(key: "query", name: tab.rawValue.capitalized, image: tab.image, trailingKind: .field)
            ])
        })
    }
}
