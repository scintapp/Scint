import SwiftUI



struct ActionsQuery: Mapper {
    static func controls(_ model: any Model) -> Controls { .init() }

    static func parameters(_ model: any Model) -> Params { .init() }
}

struct ContentQuery: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.open(ref)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let query = (model as? PanelsModel)?.search.state.query ?? ""
        let items = model.search("\(query) !scene", limit: 50).all.map { result in
            let icon = Iconography.icon(for: result.ref)
            return ItemParams(
                ref: result.ref,
                name: result.name,
                image: icon.symbol,
                tint: icon.tint,
                description: result.description
            )
        }

        return .init(
            nesting: .recursive,
            header: false,
            components: [
                .init(
                    id: "scenes",
                    name: "Scenes",
                    header: false,
                    items: items
                ),
            ],
        )
    }
}

struct InterfacesQuery: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let query = (model as? PanelsModel)?.search.state.query ?? ""
        let items = model.search("\(query) !interface", limit: 50).all.map { result in
            let icon = Iconography.icon(for: result.ref)
            return ItemParams(
                ref: result.ref,
                name: result.name,
                image: icon.symbol,
                tint: icon.tint,
                description: result.description
            )
        }
        let artifacts = items.filter { $0.ref?.type is Artifact.Type }
        let commands = items.filter { $0.ref?.type is Command.Type }
        let harnesses = items.filter { $0.ref?.type is Harness.Type }

        return .init(
            nesting: .flat,
            components: [
                .init(id: "artifacts", name: "Artifacts", items: artifacts),
                .init(id: "commands", name: "Commands", items: commands),
                .init(id: "harnesses", name: "Harnesses", items: harnesses),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct WorkspaceQuery: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let query = (model as? PanelsModel)?.search.state.query ?? ""
        let results = model.search("\(query) !space", limit: 50).all.map { result in
            let icon = Iconography.icon(for: result.ref)
            return ItemParams(
                ref: result.ref,
                name: result.name,
                image: icon.symbol,
                tint: icon.tint,
                description: result.description
            )
        }

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: results
                )
            ]
        )
    }
}

struct EverythingQuery: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is any Malleable.Type { model.open(ref) }
                else { model.select(ref) }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let limit = 50 / SearchPanel.Mode.allCases.count
        let content = ContentQuery.parameters(model).components.flatMap(\.items).prefix(limit)
        let interfaces = InterfacesQuery.parameters(model).components.flatMap(\.items).prefix(limit)
        let workspace = WorkspaceQuery.parameters(model).components.flatMap(\.items).prefix(limit)

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "content",
                    name: "Content",
                    header: false,
                    image: "text.alignleft",
                    items: Array(content)
                ),
                .init(
                    id: "interfaces",
                    name: "Interfaces",
                    header: false,
                    image: "switch.2",
                    items: Array(interfaces)
                ),
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: false,
                    image: "cube.transparent",
                    items: Array(workspace)
                )
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct PanelQuery: Mapper {
    static func controls(_ model: any Model) -> Controls {
        guard let panel = (model as? PanelsModel)?.search else { return .init() }

        var controls = switch panel.mode {
            case .everything: EverythingQuery.controls(model)
            case .content: ContentQuery.controls(model)
            case .interfaces: InterfacesQuery.controls(model)
            case .workspace: WorkspaceQuery.controls(model)
        }

        let onChange = controls.onChange
        let onValueChange = controls.onValueChange
        let onSelect = controls.onSelect
        let onAction = controls.onAction

        controls.onChange = { item, selection in
            guard let key = selection.key, let mode = SearchPanel.Mode(rawValue: key) else {
                onChange?(item, selection)
                return
            }
            panel.mode = mode
            panel.state.query = ""
        }

        controls.onValueChange = { item, value in
            guard item.key == "query" else {
                onValueChange?(item, value)
                return
            }
            panel.state.query = value
        }

        controls.onSelect = { item in
            onSelect?(item)
            panel.state.query = ""
        }

        controls.onAction = { item in
            if let onAction { onAction(item) }
            else { onSelect?(item) }
            panel.state.query = ""
        }
        return controls
    }

    static func parameters(_ model: any Model) -> Params {
        guard let panel = (model as? PanelsModel)?.search else { return .init() }

        let content = switch panel.mode {
            case .everything: EverythingQuery.parameters(model)
            case .content: ContentQuery.parameters(model)
            case .interfaces: InterfacesQuery.parameters(model)
            case .workspace: WorkspaceQuery.parameters(model)
        }

        let surfaces = SearchPanel.Mode.allCases.map { surface in
            ItemParams(key: surface.rawValue, name: surface.label, image: surface.image)
        }

        return .init(
            id: "panel",
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
                    name: panel.mode.placeholder,
                    image: panel.mode.image,
                    value: panel.state.query
                ),
                items: surfaces,
                selection: surfaces.first { $0.key == panel.mode.rawValue },
                layout: .float
            ),
            components: content.components
        )
    }

//    static func controls(_ model: any Model) -> Controls {
//        let panel = model.panel
//        var controls = switch panel.model {
//            case .everything: SearchMap.controls(model)
//            case .content: ContentPalette.controls(model)
//            case .interfaces: InterfacesMap.controls(model)
//            case .workspace: StructuresMap.controls(model)
//        }
//
//        let onChange = controls.onChange
//        let onValueChange = controls.onValueChange
//        let onSelect = controls.onSelect
//        let onAction = controls.onAction
//
//        controls.onChange = { item, selection in
//            guard let key = selection.key, let model = Palette.PanelsModel(rawValue: key) else {
//                onChange?(item, selection)
//                return
//            }
//            panel.model = model
//            panel.query = ""
//        }
//        controls.onValueChange = { item, value in
//            guard item.key == "query" else {
//                onValueChange?(item, value)
//                return
//            }
//            panel.query = value
//        }
//        controls.onAction = { item in
//            if let onAction { onAction(item) }
//            else { onSelect?(item) }
//            panel.query = ""
//        }
//        return controls
//    }

//    static func parameters(_ model: any Model) -> Params {
//        let panel = model.panel
//        let content = switch panel.model {
//            case .everything: SearchMap.parameters(model)
//            case .content: ContentPalette.parameters(model)
//            case .interfaces: InterfacesMap.parameters(model)
//            case .workspace: StructuresMap.parameters(model)
//        }
//
//        return .init(
//            id: "panel",
//            ref: content.ref,
//            name: content.name,
//            description: content.description,
//            layout: content.layout,
//            nesting: content.nesting,
//            header: content.header,
//            panel: .init(
//                size: CGSize(width: 640, height: 480),
//                input: .init(
//                    key: "query",
//                    name: panel.model.placeholder,
//                    image: panel.model.image,
//                    value: panel.query
//                ),
//                items: Palette.PanelsModel.allCases.map(surface),
//                selection: surface(panel.model),
//                layout: .float,
//                dismissal: [.escape]
//            ),
//            components: content.components
//        )
//    }
}
