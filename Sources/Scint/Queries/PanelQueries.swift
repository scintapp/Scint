import SwiftUI


struct AssistantNavigator: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Transcript.Type { return model.session.transcript == ref }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
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
        let spaces = SpacesList
            .parameters(model)
            .sections
            .flatMap { $0.items }

        let transcripts = TranscriptsList
            .parameters(model)
            .sections
            .flatMap { $0.items }

        let materials = MaterialsList
            .parameters(model)
            .sections
            .flatMap { $0.items }


        return .init(
            nesting: .recursive,
            header: true,
            sections: [
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: true,
                    items: spaces
                ),
                .init(
                    id: "materials",
                    name: "Recent Materials",
                    header: true,
                    items: materials
                ),
                .init(
                    id: "transcripts",
                    name: "Recent Transcripts",
                    header: true,
                    items: transcripts
                )
            ]
        )
    }
}
