import AgencyRuntime
import SwiftUI


struct MenuMap: Mapper {
    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.app.actions.query
        let content = Runtime.shared.search(query, limit: 8).all
        let interfaces = Runtime.shared.search(query, limit: 8).all
        let workspace = Runtime.shared.search(query,  limit: 8).all

        return .init(
            nesting: .flat,
            components: [
                .init(id: "content", name: "Content", image: "text.alignleft", items: content.map(item(from:))),
                .init(id: "interfaces", name: "Interfaces", image: "arrow.2.squarepath", items: interfaces.map(item(from:))),
                .init(id: "workspace", name: "Workspace", image: "cube.transparent", items: workspace.map(item(from:)))
            ]
        )
    }
}

struct SearchMap: Mapper {
    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.app.actions.query
        let content = Runtime.shared.search(query, limit: 20).all
        let interfaces = Runtime.shared.search(query, limit: 20).all
        let workspace = Runtime.shared.search(query, limit: 20).all

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "content",
                    name: "Content",
                    header: false,
                    image: "text.alignleft",
                    items: content.map(item(from:))
                ),
                .init(
                    id: "interfaces",
                    name: "Interfaces",
                    header: false,
                    image: "switch.2",
                    items: interfaces.map(item(from:))
                ),
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: false,
                    image: "cube.transparent",
                    items: workspace.map(item(from:))
                )
            ]
        )
    }
}

struct ContentActions: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        func selected(_ item: ItemParams) -> Bool {
            guard let ref = item.ref else { return false }
            if let url = item.path { return agency.session.selected.selected(ref, url) }
            return agency.session.selected.selected(ref)
        }

        func select(_ item: ItemParams) {
            guard let ref = item.ref else { return }
            agency.select(ref)
        }

        return .init(
            selected: selected,
            onSelect: select,
            itemActions: { item in item.path == nil ? Action.itemItems(for: item) : [] },
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let owner = agency.session.selected.space ?? agency.session.workspace
        let closure = Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

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
            components: [
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

struct ComponentsMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.app.actions.query
        let sheets = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Sheet.Type }
        let transcripts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Transcript.Type }

        return .init(
            nesting: .flat,
            components: [
                .init(id: "sheets", name: "Sheets", items: sheets.map(item(from:))),
                .init(id: "transcripts", name: "Transcripts", items: transcripts.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct InterfacesMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.app.actions.query
        let artifacts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Artifact.Type }
        let controls = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Command.Type }
        let services = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Harness.Type }

        return .init(
            nesting: .flat,
            components: [
                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
                .init(id: "controls", name: "Controls", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", items: services.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct StructuresMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.app.actions.query
        let results = Runtime.shared.search(query, limit: 50).all.filter {
            $0.ref.type is Space.Type
        }

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "space",
                    name: "Space",
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct ActionsMaps: Mapper {
    private static func surface(_ model: ActionsModel) -> ItemParams {
        .init(
            key: model.rawValue,
            name: model.label,
            image: model.image
        )
    }

    static func controls(_ agency: AgencyModel) -> Controls {
        let actions = agency.app.actions
        var controls = switch actions.model {
            case .everything: SearchMap.controls(agency)
            case .content: ContentActions.controls(agency)
            case .interfaces: InterfacesMap.controls(agency)
            case .workspace: StructuresMap.controls(agency)
        }

        let onChange = controls.onChange
        let onValueChange = controls.onValueChange
        let onSelect = controls.onSelect
        let onAction = controls.onAction

        controls.onChange = { item, selection in
            guard let key = selection.key, let model = ActionsModel(rawValue: key) else {
                onChange?(item, selection)
                return
            }
            actions.model = model
            actions.query = ""
        }
        controls.onValueChange = { item, value in
            guard item.key == "query" else {
                onValueChange?(item, value)
                return
            }
            actions.query = value
        }
        controls.onAction = { item in
            if let onAction { onAction(item) }
            else { onSelect?(item) }
            actions.query = ""
            agency.app.panels.hide(actions, in: agency)
        }
        return controls
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let actions = agency.app.actions
        let content = switch actions.model {
            case .everything: SearchMap.parameters(agency)
            case .content: ContentActions.parameters(agency)
            case .interfaces: InterfacesMap.parameters(agency)
            case .workspace: StructuresMap.parameters(agency)
        }

        return .init(
            id: "actions",
            ref: content.ref,
            name: content.name,
            description: content.description,
            layout: content.layout,
            nesting: content.nesting,
            header: content.header,
            panel: .init(
                size: CGSize(width: 640, height: 480),
                input: .init(
                    key: "query",
                    name: actions.model.placeholder,
                    image: actions.model.image,
                    value: actions.query
                ),
                items: ActionsModel.allCases.map(surface),
                selection: surface(actions.model),
                layout: .float,
                dismissal: [.escape]
            ),
            components: content.components
        )
    }
}

