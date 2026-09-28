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
                model.focus(ref)
            },
            surfaceDropTarget: {
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref, model: model) })
            },
            wrapHeader: { view, section in
                if section.id == AnyHashable("projects") {
                    return AnyView(view.contextMenu { ContextActionMenu(ref: model.session.projects, model: model) })
                }
                if section.id == AnyHashable("library") {
                    return AnyView(view.contextMenu { ContextActionMenu(ref: model.session.library, model: model) })
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

        let spaceItems = ProjectsList
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
                            ref: model.session.inbox,
                            name: "Inbox",
                            image: "tray",
                            tint: Style.Foreground.secondary
                        ),
                        .init(
                            ref: model.session.library,
                            name: "Documents",
                            image: "document.on.document",
                            tint: Style.Foreground.secondary
                        ),
                        .init(
                            ref: model.session.tasks,
                            name: "Tasks",
                            image: "checkmark.app",
                            tint: Style.Foreground.secondary
                        )
                    ]
                ),
                .init(
                    id: "projects",
                    name: "Projects",
                    header: true,
                    items: spaceItems
                ),
                .init(
                    id: "library",
                    name: "Library",
                    header: true,
                    items: libraryItems
                )
            ]
        )
    }
}
