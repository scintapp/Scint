import SwiftUI
import ScintRuntime
import ScintComponents


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
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref, model: model) })
            },
            wrapHeader: { view, section in
                if section.id == AnyHashable("spaces") {
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
                    id: "spaces",
                    name: "Spaces",
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
                let space = model.session.projects
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

        let documents = DocumentsList
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
                    id: "documents",
                    name: "Recent Documents",
                    header: true,
                    items: documents
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

struct DocumentQuery: Query {
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
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let doc = model.session.selection.content, let blocks = Document.with(doc, { $0.blocks })
        else { return .init() }

        let blockItems = blocks.compactMap {
            switch $0 {
                case .artifact(let ref):
                    return ItemParams(ref: ref, name: ref.descriptor.name)
                case .text(_, let content):
                    return ItemParams(name: content)
                default:
                    return ItemParams(name: "")
            }
        }

        return .init(
            id: "outline",
            name: "Outline",
            header: false,
            sections: [
                .init(
                    id: "space",
                    name: "Workspace",
                    header: true,
                    items: blockItems
                ),
            ]
        )
    }
}

struct SpaceOutlineQuery: Query {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let artifacts = ArtifactsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-artifacts" || key == "add-files" { return artifacts }
                return harness
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Harness.Type { return harness }
            return artifacts
        }

        return .init(
            onToggle: { item in source(for: item).onToggle?(item) },
            onChange: { item, selection in source(for: item).onChange?(item, selection) },
            onValueChange: { item, value in source(for: item).onValueChange?(item, value) },
            onSelect: { item in source(for: item).onSelect?(item) },
            onAction: { item in source(for: item).onAction?(item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.projects }
        }
        guard let space = focused else { return .init() }

        return .init(
            ref: space,
            layout: .group,
            header: true,
            sections: DocumentsGroup.parameters(model).sections + ArtifactsGroup.parameters(model).sections
        )
    }
}

struct SpaceSettingsQuery: Query {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let artifacts = ArtifactsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-artifacts" || key == "add-files" { return artifacts }
                return harness
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Harness.Type { return harness }
            return artifacts
        }

        return .init(
            onToggle: { item in source(for: item).onToggle?(item) },
            onChange: { item, selection in source(for: item).onChange?(item, selection) },
            onValueChange: { item, value in source(for: item).onValueChange?(item, value) },
            onSelect: { item in source(for: item).onSelect?(item) },
            onAction: { item in source(for: item).onAction?(item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.projects }
        }
        guard let space = focused else { return .init() }

        return .init(
            ref: space,
            layout: .group,
            header: true,
            sections: HarnessGroup.parameters(model).sections + CommandsGroup.parameters(model).sections
        )
    }
}


