import SwiftUI


struct NavigatorQuery: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus == .structure(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceDropTarget: {
                .init(name: "Spaces")
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref) })
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                target.ref == nil ? ReferenceTransfer.detach(providers) : ReferenceTransfer.handle(providers, target: target)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            header: true,
            sections: [
                .init(
                    id: "base",
                    header: false,
                    items: [
                        .init(
                            name: "Drafts",
                            image: "tray"
                        ),
                        .init(
                            name: "Scheduled",
                            image: "calendar"
                        ),
                        .init(
                            name: "Tasks",
                            image: "figure.walk.diamond"
                        )
                    ]
                ),
                .init(
                    id: "spaces",
                    name: "Spaces",
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

struct PathQuery: Query {
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
                guard section.id == AnyHashable("spaces"), let space = model.session.space else { return nil }
                return .init(ref: space, name: space.descriptor.name)
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
            header: true,
            sections: [
                .init(
                    id: "space",
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

struct CanvasQuery: Query {
    static func controls(_ model: any Model) -> Controls { .init() }
    static func parameters(_ model: any Model) -> Params { .init() }
}

