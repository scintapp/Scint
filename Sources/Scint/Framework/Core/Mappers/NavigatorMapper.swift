import SwiftUI
import ScintRuntime
import ScintComponents


struct NavigatorMapper: Mapper {
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
            },
            surfaceDropTarget: {
                let space = model.session.spaces
                return .init(ref: space, name: space.descriptor.name)
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextMenu(ref: ref, model: model) })
            },
            wrapHeader: { view, section in
                if section.id == AnyHashable("spaces") {
                    return AnyView(view.contextMenu { ContextMenu(ref: model.session.spaces, model: model) })
                }
                if section.id == AnyHashable("library") {
                    return AnyView(view.contextMenu { ContextMenu(ref: model.session.library, model: model) })
                }
                if section.id == AnyHashable("tasks") {
                    return AnyView(view.contextMenu { ContextMenu(ref: model.session.tasks, model: model) })
                }
                return view
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                guard let ref = target.ref else { return ReferenceTransfer.detach(providers) }
                let sharing = !Navigation().spaces(to: ref).contains(model.session.library)
                return ReferenceTransfer.handle(providers, target: target, sharing: sharing)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let libraryItems = LibraryList
            .parameters(model)
            .sections
            .flatMap { $0.items }

        let spaceItems = SpacesList
            .parameters(model)
            .sections
            .flatMap { $0.items }

        let _ = TagsList
            .parameters(model)
            .sections
            .flatMap { $0.items }

        return .init(
            header: true,
            sections: [
                .init(
                    id: "base",
                    header: false,
                    items: [
                        .init(
                            ref: model.session.tasks,
                            name: "Agenda",
                            image: "calendar",
                            tint: Style.Foreground.secondary
                        ),
                        .init(
                            ref: model.session.library,
                            name: "Documents",
                            image: "document.on.document",
                            tint: Style.Foreground.secondary
                        ),
                        .init(
                            ref: model.session.inbox,
                            name: "Spaces",
                            image: "cube.transparent",
                            tint: Style.Foreground.secondary
                        ),
                    ]
                ),
                .init(
                    id: "spaces",
                    name: "Spaces",
                    header: true,
                    disclosable: true,
                    items: spaceItems
                ),
                .init(
                    id: "library",
                    name: "Library",
                    header: true,
                    disclosable: true,
                    items: libraryItems
                )
            ]
        )
    }
}
