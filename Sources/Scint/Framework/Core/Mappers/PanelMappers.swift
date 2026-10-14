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

    static func narrowed(_ sections: [SectionParams], by query: String) -> [SectionParams] {
        sections.enumerated()
            .compactMap { place, section -> (section: SectionParams, place: Int, score: Double)? in
                var section = section
                section.items = narrowed(section.items, by: query)
                guard let best = section.items.first else { return nil }
                return (section, place, Search.score(query, name: best.name, description: best.description, terms: best.keywords))
            }
            .sorted { $0.score == $1.score ? $0.place < $1.place : $0.score > $1.score }
            .map(\.section)
    }
}

struct ReferenceList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(results: { section, query in
            var section = section
            section.items = model.search(query, filters: [section.id.base as? String ?? ""], limit: 24).all.map {
                ItemParams(ref: $0.ref, name: $0.ref.descriptor.name, description: $0.ref.descriptor.description)
            }
            return [section]
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
        .map { ItemParams(key: $0.name.lowercased(), name: $0.name, description: $0.value, actionable: false) }

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
                    SectionParams(id: section.name, name: section.name, layout: .list, items: section.items.filter { $0.enabled(app) }.map {
                        ItemParams(key: section.name, name: $0.label, image: $0.image, value: $0.id, keywords: $0.keywords + [section.name])
                    })
                }, by: query)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            description: "No matches",
            input: ItemParams(key: "query", name: "Actions", image: "command", trailingKind: .field),
            sections: [.init(id: "actions", header: false, layout: .list)]
        )
    }
}

struct SearchList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let app: Model = (model as? PanelModel)?.app ?? model

        return .init(
            selected: { item in item.ref.map { model.session.selection.selected($0) } ?? false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any ScintRuntime.Material.Type { app.open(ref) }
                else { app.select(ref) }
            },
            onAction: { item in if let ref = item.ref { model.focus(ref) } },
            results: ReferenceList.controls(model).results
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(description: "No matches", tabbed: true, sections: [
            .init(id: "everything", name: "Everything", header: false, image: "magnifyingglass", layout: .list, sections: [
                .init(id: "document", name: "Content", layout: .list),
                .init(id: "interface", name: "Interfaces", layout: .list),
                .init(id: "structure", name: "Workspace", layout: .list)
            ]),
            .init(id: "content", name: "Content", header: false, image: "command", layout: .list, sections: [
                .init(id: "document", layout: .list)
            ]),
            .init(id: "interfaces", name: "Interfaces", header: false, image: "switch.2", layout: .list, sections: [
                .init(id: "artifact", name: "Artifacts", layout: .list),
                .init(id: "command", name: "Commands", layout: .list),
                .init(id: "harness", name: "Harnesses", layout: .list)
            ]),
            .init(id: "projects", name: "Projects", header: false, image: "cube.transparent", layout: .list, sections: [
                .init(id: "structure", layout: .list)
            ])
        ])
    }
}
