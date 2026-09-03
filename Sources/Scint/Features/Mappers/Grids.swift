import SwiftUI


struct SpaceGrid: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focused == .structure(ref)
                || model.session.focused == .interface(ref)
                || model.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { model.select(ref) }
                else { model.open(ref) }
            },
            surfacePalette: {
                guard let origin = model.session.selected.structure else { return [] }
                return Action.surfaceItems(for: origin)
            },
            surfaceDropTarget: {
                model.session.selected.structure.map { .init(ref: $0, name: $0.descriptor.name) }
            },
            itemPalette: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let ref = model.session.origin
        let materials = Space.with(ref, { $0.materials }) ?? []
        let spaces = Space.with(ref, { $0.spaces }) ?? []

        let structures: [ItemParams] = spaces
            .filter { $0.descriptor.published != false }
            .compactMap { space in
                    .init(
                        ref: space,
                        origin: space,
                        name: space.descriptor.name,
                        image: Iconography.icon(for: space).symbol
                    )
            }

        let content: [ItemParams] = materials
            .filter { $0.descriptor.published != false }
            .compactMap { material in
                    .init(
                        ref: material,
                        origin: Material.with(material, { $0.origin }),
                        name: material.descriptor.name,
                        image: Iconography.icon(for: material).symbol
                    )
            }

        return .init(
            layout: .grid,
            sections: [
                .init(
                    id: "space",
                    header: false,
                    items: structures + content.filter { $0.ref?.type == Material.self && $0.name != "Input" }
                ),
            ]
        )
    }
}
