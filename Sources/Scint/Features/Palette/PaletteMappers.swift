import SwiftUI


struct ContentPalette: Mapper {
    static func controls(_ model: any Model) -> Controls {
        func selected(_ item: ItemParams) -> Bool {
            guard let ref = item.ref else { return false }
            if let url = item.path { return model.session.selected.selected(ref, url) }
            return model.session.selected.selected(ref)
        }

        func select(_ item: ItemParams) {
            guard let ref = item.ref else { return }
            model.select(ref)
        }

        return .init(
            selected: selected,
            onSelect: select,
            itemPalette: { item in item.path == nil ? Action.itemItems(for: item) : [] },
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let owner = model.session.selected.space ?? model.session.workspace
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

struct InterfacePalette: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

//    static func parameters(_ model: any Model) -> Params {
//        let query = model.palette.query
//        let artifacts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Artifact.Type }
//        let controls = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Command.Type }
//        let services = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Harness.Type }
//
//        return .init(
//            nesting: .flat,
//            components: [
//                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
//                .init(id: "controls", name: "Controls", items: controls.map(item(from:))),
//                .init(id: "services", name: "Harness", items: services.map(item(from:))),
//            ].filter { !$0.items.isEmpty }
//        )
//    }
}

struct WorkspacePalette: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

//    static func parameters(_ model: any Model) -> Params {
//        let query = model.palette.query
//        let results = Runtime.shared.search(query, limit: 50).all.filter {
//            $0.ref.type is Space.Type
//        }
//
//        return .init(
//            nesting: .flat,
//            components: [
//                .init(
//                    id: "space",
//                    name: "Space",
//                    items: results.map(item(from:))
//                )
//            ]
//        )
//    }
}

struct PaletteMap: Mapper {
    //    static func parameters(_ model: any Model) -> Params {
    //        let query = model.palette.query
    //        let content = Runtime.shared.search(query, limit: 20).all
    //        let interfaces = Runtime.shared.search(query, limit: 20).all
    //        let workspace = Runtime.shared.search(query, limit: 20).all
    //
    //        return .init(
    //            nesting: .flat,
    //            components: [
    //                .init(
    //                    id: "content",
    //                    name: "Content",
    //                    header: false,
    //                    image: "text.alignleft",
    //                    items: content.map(item(from:))
    //                ),
    //                .init(
    //                    id: "interfaces",
    //                    name: "Interfaces",
    //                    header: false,
    //                    image: "switch.2",
    //                    items: interfaces.map(item(from:))
    //                ),
    //                .init(
    //                    id: "workspace",
    //                    name: "Workspace",
    //                    header: false,
    //                    image: "cube.transparent",
    //                    items: workspace.map(item(from:))
    //                )
    //            ]
    //        )
    //    }
}

struct PaletteMaps: Mapper {
//    static func controls(_ model: any Model) -> Controls {
//        let palette = model.palette
//        var controls = switch palette.model {
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
//            guard let key = selection.key, let model = Palette.PaletteModel(rawValue: key) else {
//                onChange?(item, selection)
//                return
//            }
//            palette.model = model
//            palette.query = ""
//        }
//        controls.onValueChange = { item, value in
//            guard item.key == "query" else {
//                onValueChange?(item, value)
//                return
//            }
//            palette.query = value
//        }
//        controls.onAction = { item in
//            if let onAction { onAction(item) }
//            else { onSelect?(item) }
//            palette.query = ""
//        }
//        return controls
//    }

//    static func parameters(_ model: any Model) -> Params {
//        let palette = model.palette
//        let content = switch palette.model {
//            case .everything: SearchMap.parameters(model)
//            case .content: ContentPalette.parameters(model)
//            case .interfaces: InterfacesMap.parameters(model)
//            case .workspace: StructuresMap.parameters(model)
//        }
//
//        return .init(
//            id: "palette",
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
//                    name: palette.model.placeholder,
//                    image: palette.model.image,
//                    value: palette.query
//                ),
//                items: Palette.PaletteModel.allCases.map(surface),
//                selection: surface(palette.model),
//                layout: .float,
//                dismissal: [.escape]
//            ),
//            components: content.components
//        )
//    }
}

struct ComponentsMap: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

//    static func parameters(_ model: any Model) -> Params {
//        let query = model.palette.query
//        let sheets = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Sheet.Type }
//        let transcripts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Transcript.Type }

//        return .init(
//            nesting: .flat,
//            components: [
//                .init(id: "sheets", name: "Sheets", items: sheets.map(item(from:))),
//                .init(id: "transcripts", name: "Transcripts", items: transcripts.map(item(from:))),
//            ].filter { !$0.items.isEmpty }
//        )
//    }
}

struct MenuMap: Mapper {
//    static func parameters(_ model: any Model) -> Params {
//        let query = model.palette.query
//        let content = Runtime.shared.search(query, limit: 8).all
//        let interfaces = Runtime.shared.search(query, limit: 8).all
//        let workspace = Runtime.shared.search(query,  limit: 8).all
//
//        return .init(
//            nesting: .flat,
//            components: [
//                .init(id: "content", name: "Content", image: "text.alignleft", items: content.map(item(from:))),
//                .init(id: "interfaces", name: "Interfaces", image: "arrow.2.squarepath", items: interfaces.map(item(from:))),
//                .init(id: "workspace", name: "Workspace", image: "cube.transparent", items: workspace.map(item(from:)))
//            ]
//        )
//    }
}
