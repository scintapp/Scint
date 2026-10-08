import SwiftUI
import ScintRuntime
import ScintComponents


struct InboxOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct InboxSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct ProjectOutline: Mapper {
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
            return nil
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

struct ProjectSettings: Mapper {
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
            return nil
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

struct DocumentOutline: Mapper {
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
                    header: false,
                    items: blockItems
                ),
            ]
        )
    }
}

struct DocumentSettings: Mapper {
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
                    header: false,
                    items: blockItems
                ),
            ]
        )
    }
}

struct TaskOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct TaskSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct InspectorOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.inbox: return InboxOutline.controls(model)
            case model.session.library: return DocumentOutline.controls(model)
            case model.session.projects: return ProjectOutline.controls(model)
            case model.session.tasks: return TaskOutline.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxOutline.parameters(model)
            case model.session.library: return DocumentOutline.parameters(model)
            case model.session.projects: return ProjectOutline.parameters(model)
            case model.session.tasks: return TaskOutline.parameters(model)
            default: return Params()
        }
    }
}

struct InspectorSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.inbox: return InboxSettings.controls(model)
            case model.session.library: return DocumentSettings.controls(model)
            case model.session.projects: return ProjectSettings.controls(model)
            case model.session.tasks: return TaskSettings.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxSettings.parameters(model)
            case model.session.library: return DocumentSettings.parameters(model)
            case model.session.projects: return ProjectSettings.parameters(model)
            case model.session.tasks: return TaskSettings.parameters(model)
            default: return Params()
        }
    }
}
