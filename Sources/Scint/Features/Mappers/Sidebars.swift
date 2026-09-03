import SwiftUI


struct LibraryNavigator: Mapper {
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
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let artifacts = ArtifactsList.parameters(model).sections
        let commands = CommandsList.parameters(model).sections
        let harnesses = HarnessesList.parameters(model).sections

        return .init(
            id: "artifacts",
            name: "Artifacts",
            nesting: .recursive,
            header: true,
            sections: artifacts + commands + harnesses
        )
    }
}

struct WorkspaceNavigator: Mapper {
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

struct SpaceInspector: Mapper {
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
        let harnessControls = HarnessGroup.parameters(model).sections
        let commandsControls = CommandsGroup.parameters(model).sections
        let artifactsControls = ArtifactsGroup.parameters(model).sections

        return .init(
            layout: .group,
            header: true,
            sections: harnessControls + commandsControls + artifactsControls
        )
    }
}
