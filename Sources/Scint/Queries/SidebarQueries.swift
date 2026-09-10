import SwiftUI


struct AssistantSidebar: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Transcript.Type { return model.session.transcript == ref }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            sectionDropTarget: { section in
                guard section.id == AnyHashable("spaces") else { return nil }
                let workspace = model.session.workspace
                return .init(ref: workspace, name: workspace.descriptor.name)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            nesting: .recursive,
            header: true,
            sections: [
                .init(
                    id: "base",
                    header: false,
                    items: [
                        .init(name: "Inbox", image: "tray"),
                        .init(name: "Library", image: "building.classical.columns"),
                        .init(name: "Outlines", image: "checklist.unchecked"),
                        .init(name: "Tasks", image: "checkmark.app"),
                    ]
                ),
                .init(
                    id: "projects",
                    name: "Projects",
                    header: true,
                    items: SpacesList
                        .parameters(model)
                        .sections
                        .flatMap { $0.items }
                )
            ]
        )
    }
}
