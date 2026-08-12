import SwiftUI


struct DetailQuery: Mapper {
    enum Verb: String { case open, execute, copy, insert }

    static func parameters(_ item: ItemParams) -> Params {
        guard let ref = item.ref else { return .init() }
        let structural = ref.type is Space.Type || ref.type is Workspace.Type

        func about() -> SectionParams {
            var items: [ItemParams] = [
                .init(key: "kind", name: "Kind", trailingKind: .value, value: ref.type.map { "\($0)" } ?? "Unknown"),
                .init(key: "updated", name: "Updated", trailingKind: .value, value: ref.descriptor.updated.formatted(date: .abbreviated, time: .shortened))
            ]
            if !ref.descriptor.tags.isEmpty {
                items.append(.init(key: "tags", name: "Tags", trailingKind: .value, value: ref.descriptor.tags.sorted().joined(separator: ", ")))
            }
            return .init(id: "about", name: "About", items: items)
        }

        func contents() -> SectionParams {
            let refs = Space.with(ref, { $0.spaces + $0.materials })
            ?? Workspace.with(ref, { $0.spaces + $0.materials })
            ?? Material.with(ref, { $0.blocks.compactMap { block in
                if case .material(let child) = block { return child }
                if case .command(let child) = block { return child }
                if case .artifact(let child) = block { return child }
                return nil
            }}) ?? []

            return .init(
                id: "contents",
                name: "Contents",
                items: refs.map { child in
                    let icon = Iconography.icon(for: child)
                    return .init(ref: child, name: child.descriptor.name, image: icon.symbol, tint: icon.tint)
                }
            )
        }

        func actions() -> SectionParams {
            var verbs: [Verb] = [.open]
            if structural { verbs.append(.execute) }
            verbs.append(contentsOf: [.copy, .insert])

            return .init(
                id: "actions",
                name: "Actions",
                items: verbs.map { verb in
                        .init(
                            ref: ref,
                            key: verb.rawValue,
                            name: verb.rawValue.capitalized,
                            image: image(verb),
                            trailingKind: .button
                        )
                }
            )
        }

        func image(_ verb: Verb) -> String {
            switch verb {
                case .open: "arrow.up.forward.square"
                case .execute: "play"
                case .copy: "doc.on.doc"
                case .insert: "text.insert"
            }
        }

        return .init(
            ref: ref,
            name: ref.descriptor.name,
            description: ref.descriptor.description,
            components: [about(), contents(), actions()].filter { !$0.items.isEmpty }
        )
    }

    static func perform(_ item: ItemParams, _ model: any Model) {
        guard let ref = item.ref, let key = item.key, let verb = Verb(rawValue: key) else { return }

        switch verb {
            case .open: model.open(ref)
            case .execute: _ = model.start(ref)
            case .copy: Action.copy(ref, from: nil, in: model)
            case .insert:
                let origin = model.session.origin
                if origin.type is Workspace.Type { Workspace.with(origin, { $0 })?.add(ref) }
                else { Space.with(origin, { $0 })?.add(ref) }
        }
    }
}

struct ActionsQuery: Mapper {
    static func controls(_ model: any Model) -> Controls { .init() }

    static func parameters(_ model: any Model) -> Params { .init() }
}

struct ContentQuery: Mapper {
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
            detail: { DetailQuery.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.open(ref)
            },
            onAction: { DetailQuery.perform($0, model) },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            nesting: .recursive,
            header: false
        )
    }
}

struct InterfacesQuery: Mapper {
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
            detail: { DetailQuery.parameters($0) },
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            onAction: { DetailQuery.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            nesting: .flat
        )
    }
}

struct WorkspaceQuery: Mapper {
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
            detail: { DetailQuery.parameters($0) },
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            onAction: { DetailQuery.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            nesting: .flat
        )
    }
}

struct EverythingQuery: Mapper {
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
            detail: { DetailQuery.parameters($0) },
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any Malleable.Type { model.open(ref) }
                else { model.select(ref) }
            },
            onAction: { DetailQuery.perform($0, model) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            nesting: .flat
        )
    }
}
