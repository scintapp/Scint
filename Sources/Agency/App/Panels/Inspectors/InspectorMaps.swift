import AgencyRuntime
import SwiftUI


struct SpaceInspector: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        var space: Reference {
            if case .structure(let ref) = agency.session.focused { return ref }
            else { return agency.session.space ?? agency.session.workspace }
        }

        let closure = (Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure }))!

        return .init(
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                Closure.update(closure) { $0.interfaces.insert(ref) }
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Harness.Type {
                    if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
                    else { Space.update(space) { $0.harness = ref } }
                    return
                }
                if let ref = item.ref, ref.type is Artifact.Type {
                    Closure.update(closure) { $0.content.remove(ref) }
                    return
                }

                let panel = NSOpenPanel()
                panel.title = "Add Files or Folders"
                panel.prompt = "Add"
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                guard panel.runModal() == .OK else { return }
                for url in panel.urls {
                    let artifact = Artifact.register(url.lastPathComponent, url)
                    if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(artifact) }
                    else { Space.with(space, { $0 })?.add(artifact) }
                }
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        var space: Reference {
            if case .structure(let ref) = agency.session.focused { return ref }
            else { return agency.session.space ?? agency.session.workspace }
        }

        let closure = (Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure }))!
        let harnesses = Closure.with(closure, { $0.harnesses })!
        let activeHarness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness })

        let library = Runtime.shared.all(as: Harness.self)
            .map { $0.0 }
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    description: ref.descriptor.description,
                    active: harnesses.contains(ref)
                )
            }

        let loaded = harnesses
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    trailingKind: ref == activeHarness ? .value : .action,
                    value: ref == activeHarness ? "Active" : "Activate",
                    description: ref.descriptor.description
                )
            }

        let loaderIcon = Iconography.Icon(symbol: "plus", tint: Design.Tint.harness)

        var components: [ComponentParams] = [
            .init(
                id: "harnesses",
                name: "Harnesses",
                items: [
                    .init(
                        name: "Harness Library",
                        image: loaderIcon.symbol,
                        tint: loaderIcon.tint,
                        trailingKind: .load,
                        count: harnesses.count,
                        items: library
                    )
                ] + loaded
            )
        ]
        components.append(
            .init(
                id: "files",
                name: "Files & Folders",
                items: [
                    .init(
                        key: "add-files",
                        name: "Add Files...",
                        image: "folder.badge.plus",
                        tint: Design.Tint.artifact,
                        trailingKind: .button
                    )
                ]
            )
        )

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: components
        )
    }
}

struct SheetInspector: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func item(for block: Sheet.Block, owner: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description
                    )
                case .text(let id, let text):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: text,
                        image: icon.symbol,
                        tint: icon.tint
                    )
                case .sheet(let ref):
                    let children = Sheet.with(ref, { sheet in
                        sheet.blocks.map { item(for: $0, owner: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description,
                        items: children
                    )
                case .task(let id, let title, _):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: title,
                        image: icon.symbol,
                        tint: icon.tint
                    )
            }
        }

        guard case .content(let sheet) = agency.session.focused, sheet.type is Sheet.Type
        else { return .init(layout: .group) }
        let items = Sheet.with(sheet, { value in value.blocks.map { item(for: $0, owner: sheet) } }) ?? []

        return .init(
            ref: sheet,
            name: sheet.descriptor.name,
            description: sheet.descriptor.description,
            layout: .group,
            nesting: .recursive,
            header: true,
            components: [
                .init(
                    id: "outline",
                    name: "Content Outline",
                    header: true,
                    items: items
                )
            ]
        )
    }
}

struct PreviewInspector: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { agency.select(ref) }
                else { agency.focus(ref) }
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.open(ref)
            },
            surfaceActions: {
                let ref: Reference
                switch agency.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = agency.session.selected.structure!
                }
                return Action.surfaceItems(for: ref)
            },
            surfaceDropTarget: {
                let ref: Reference
                switch agency.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = agency.session.selected.structure!
                }
                return .init(ref: ref, name: ref.descriptor.name)
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ studio: AgencyModel) -> Params {
        .init(
            layout: .group,
            components: [
                .init(
                    id: "context",
                    name: "Context",
                    footer: "A preview of this space's context, as the agent or model sees it."
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    footer: "An estimate of the tokens required to process this space.",
                    items: [
                        .init(name: "Input Tokens",  trailingKind: .value, description: "0"),
                        .init(name: "Cached Tokens", trailingKind: .value, description: "0"),
                        .init(name: "Output Tokens", trailingKind: .value, description: "0"),
                    ]
                ),
            ]
        )
    }
}

struct InspectorMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        switch agency.app.inspector.model {
            case .space: SpaceInspector.controls(agency)
            case .sheet: SheetInspector.controls(agency)
        }
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        switch agency.app.inspector.model {
            case .space: SpaceInspector.parameters(agency)
            case .sheet: SheetInspector.parameters(agency)
        }
    }
}
