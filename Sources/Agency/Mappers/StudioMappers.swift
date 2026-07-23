import AgencyRuntime
import SwiftUI


struct ContentMapper: Mapper {
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
            surfaceActions: {
                guard let owner = model.session.selected.space else { return [] }
                return Action.surfaceItems(for: owner)
            },
            surfaceDropTarget: {
                model.session.selected.space.map { .init(ref: $0, name: $0.descriptor.name) }
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let ref = model.session.selected.space else { return DashboardMap.parameters(model) }
        let space = Space.with(ref, { $0 })
        let content = space.flatMap { $0.sheets + $0.transcripts } ?? []
        let spaces = Space.with(ref, { $0.spaces }) ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { child in
                return .init(
                    ref: child,
                    origin: ref,
                    name: child.descriptor.name
                )
            }

        let contentItems: [ItemParams] = content.compactMap { ref in
                .init(
                    ref: ref,
                    origin: ref,
                    name: ref.descriptor.name,
                    image: Iconography.icon(for: ref).symbol
                )
        }

        return .init(
            layout: .list,
            components: [
                .init(
                    id: "content",
                    header: false,
                    items: spaceItems + contentItems.filter { $0.ref?.type == Sheet.self && $0.name != "Input" }
                ),
            ]
        )
    }
}

struct DashboardMap: Mapper {
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
            surfaceActions: {
                Action.surfaceItems(for: model.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: model.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let spaces = Workspace.with(model.session.workspace, { $0.spaces }) ?? []
        let closure = Workspace.with(model.session.workspace, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { space in
                return .init(
                    ref: space,
                    origin: model.session.workspace,
                    name: space.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
                .init(
                    ref: ref,
                    origin: model.session.workspace,
                    name: ref.descriptor.name,
                    image: Iconography.icon(for: ref).symbol
                )
        }

        return .init(
            layout: .grid,
            components: [
                .init(
                    id: "space",
                    header: false,
                    items: spaceItems + stateItems.filter { $0.ref?.type == Sheet.self && $0.name != "Input" }
                )
            ]
        )
    }
}

struct SpaceInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.space ?? model.session.workspace }
        }

        func add(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(ref) }
            else { Space.with(space, { $0 })?.add(ref) }
        }

        func remove(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.remove(ref) }
            else { Space.with(space, { $0 })?.remove(ref) }
        }

        func configure(_ value: AgencyRuntime.Value?, for key: String) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.configure(value, for: key) }
            else { Space.with(space, { $0 })?.configure(value, for: key) }
        }

        return .init(
            onToggle: { item in
                guard let key = item.key else { return }
                configure(.bool(!item.active), for: key)
            },
            onChange: { item, selection in
                guard let key = item.key else { return }
                configure(selection.value.map(AgencyRuntime.Value.string), for: key)
            },
            onValueChange: { item, value in
                guard let key = item.key else { return }
                configure(value.isEmpty ? nil : .string(value), for: key)
            },
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                add(ref)
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Harness.Type {
                    if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
                    else { Space.update(space) { $0.harness = ref } }
                    return
                }
                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    remove(ref)
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

    static func parameters(_ model: any Model) -> Params {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.space ?? model.session.workspace }
        }

        func options(_ value: AgencyRuntime.Value) -> [AgencyRuntime.Value] {
            switch value {
                case .collection(let values) where values.count == 1:
                    return values.values.first.map(options) ?? []
                case .sequence(let values) where values.count > 1:
                    return values
                default:
                    return []
            }
        }

        func leaf(_ value: AgencyRuntime.Value) -> AgencyRuntime.Value {
            switch value {
                case .collection(let values) where values.count == 1:
                    return values.values.first.map(leaf) ?? value
                case .sequence(let values) where values.count > 1:
                    return values.first.map(leaf) ?? value
                default:
                    return value
            }
        }

        func label(_ value: String) -> String {
            value.reduce(into: "") { label, character in
                if character == "-" || character == "_" { label.append(" ") }
                else {
                    if character.isUppercase, !label.isEmpty { label.append(" ") }
                    label.append(character)
                }
            }.capitalized
        }

        let commands = Space.with(space, { $0.commands }) ?? Workspace.with(space, { $0.commands }) ?? []
        let harnesses = Space.with(space, { $0.harnesses }) ?? Workspace.with(space, { $0.harnesses }) ?? []
        let harness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness })
        let config = Space.with(space, { $0.config }) ?? Workspace.with(space, { $0.config }) ?? [:]
        let parameters = harness.flatMap { Harness.with($0, { $0.parameters }) } ?? []
        let executionItems = parameters.compactMap { parameter -> ItemParams? in
            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
                  !required,
                  key != "continuation"
            else { return nil }

            let configured = config[key]
            let selected = configured?.rendered.last ?? ""
            let choices = options(type)
            if !choices.isEmpty {
                var items = choices.compactMap { value -> ItemParams? in
                    guard let rendered = value.rendered.last, !rendered.isEmpty else { return nil }
                    return .init(name: label(rendered), value: rendered)
                }
                if !selected.isEmpty, !items.contains(where: { $0.value == selected }) {
                    items.append(.init(name: label(selected), value: selected))
                }
                return .init(
                    key: key,
                    name: label(key),
                    image: "slider.horizontal.3",
                    tint: Design.Tint.command,
                    trailingKind: .picker,
                    value: selected,
                    items: [.init(name: "Default")] + items
                )
            }

            switch leaf(type) {
                case .bool:
                    let active = if case .bool(let value) = configured {
                        value
                    } else if let defaultValue, case .bool(let value) = leaf(defaultValue) {
                        value
                    } else {
                        false
                    }
                    return .init(
                        key: key,
                        name: label(key),
                        image: "switch.2",
                        tint: Design.Tint.command,
                        trailingKind: .toggle,
                        active: active
                    )
                case .string, .integer, .decimal:
                    return .init(
                        key: key,
                        name: label(key),
                        image: "slider.horizontal.3",
                        tint: Design.Tint.command,
                        trailingKind: .field,
                        value: selected
                    )
                case .sequence, .collection, .reference:
                    return nil
            }
        }

        let artifacts = (Space.with(space, { $0.artifacts }) ?? Workspace.with(space, { $0.artifacts }) ?? []).filter { ref in
            Artifact.with(ref) { artifact in
                switch artifact.handler {
                    case .app, .directory, .file, .image, .script, .skill, .executable: true
                    case .bookmark: false
                }
            }!
        }.map { ref in
            ItemParams(
                ref: ref,
                name: ref.descriptor.name,
                trailingKind: .remove
            )
        }

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
                    trailingKind: ref == harness ? .value : .action,
                    value: ref == harness ? "Active" : "Activate",
                    description: ref.descriptor.description
                )
            }

        let commandLibrary = Runtime.shared.all(as: Command.self)
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
                    active: commands.contains(ref)
                )
            }

        let loadedCommands = commands
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
                    trailingKind: .remove,
                    description: ref.descriptor.description
                )
            }

        let loaderIcon = Iconography.Icon(symbol: "plus", tint: Design.Tint.harness)
        let commandLoaderIcon = Iconography.Icon(symbol: "plus", tint: Design.Tint.command)

        var components: [ComponentParams] = [
            .init(
                id: "harnesses",
                name: "Harnesses",
                items: [
                    .init(
                        name: "Add Harnesses...",
                        image: loaderIcon.symbol,
                        tint: loaderIcon.tint,
                        trailingKind: .load,
                        items: library
                    )
                ] + loaded
            ),
            .init(
                id: "commands",
                name: "Commands",
                items: [
                    .init(
                        name: "Add Commands...",
                        image: commandLoaderIcon.symbol,
                        tint: commandLoaderIcon.tint,
                        trailingKind: .load,
                        items: commandLibrary
                    )
                ] + loadedCommands
            )
        ]
        if !executionItems.isEmpty {
            components.append(.init(id: "execution", name: "Execution", items: executionItems))
        }
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
                ] + artifacts
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

struct PreviewInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { model.select(ref) }
                else { model.focus(ref) }
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                model.open(ref)
            },
            surfaceActions: {
                let ref: Reference
                switch model.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = model.session.selected.structure!
                }
                return Action.surfaceItems(for: ref)
            },
            surfaceDropTarget: {
                let ref: Reference
                switch model.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = model.session.selected.structure!
                }
                return .init(ref: ref, name: ref.descriptor.name)
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ studio: any Model) -> Params {
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

struct LocationsNavigator: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let expanded = (model as? StudioModel)?.library.state.expanded ?? []

        func sortFileItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.isParent
                let rhsDirectory = $1.isParent
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Handler, root: Reference, in model: some Model) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let children: [ItemParams] = entry.directory && expanded.contains(AnyHashable(url))
            ? sortFileItems(model.files.children(for: entry).compactMap { file(for: $0, root: root, in: model) })
            : []

            return .init(
                ref: root,
                path: url,
                name: entry.name,
                image: entry.directory ? "folder" : "doc",
                items: children,
                isParent: entry.directory
            )
        }

        func folder(for ref: Reference, in model: some Model) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.handler }), let url = entry.url else { return nil }
            let isDirectory = entry.directory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = isDirectory && isExpanded
            ? sortFileItems(model.files.children(for: entry).compactMap { file(for: $0, root: ref, in: model) })
            : []

            return .init(
                ref: ref,
                path: url,
                name: Runtime.shared.get(ref).name,
                image: isDirectory ? "folder" : "doc",
                items: children,
                isParent: isDirectory
            )
        }

        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFileItems(model.files.artifacts.compactMap { folder(for: $0, in: model) })
                )
            ]
        )
    }
}

struct SpacesNavigator: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: model.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: model.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Space.Type
                let rhsBoundary = $1.ref?.type is Space.Type
                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func space(for ref: Reference, owner: Reference, in model: some Model) -> ItemParams {
            let spaces = Space.with(ref, { $0.spaces.map { space(for: $0, owner: ref, in: model) }}) ?? []

            return .init(
                ref: ref,
                origin: owner,
                name: ref.descriptor.name,
                image: "app",
                items: sorted(spaces)
            )
        }

        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: sorted(Workspace.with(model.session.workspace, {
                        $0.spaces.map { space(for: $0, owner: model.session.workspace, in: model) } }) ?? [])
                )
            ]
        )
    }
}

struct WorkspaceNavigator: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let sheets = SheetsNavigator.controls(model)

        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Sheet.Type { return sheets.selected?(item) ?? false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: model.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: model.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, depth in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                guard let accessory = sheets.itemLeadingAccessory else { return nil }
                return accessory(item, depth)
            },
            itemAccessory: { item, depth in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                guard let accessory = sheets.itemAccessory else { return nil }
                return accessory(item, depth)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {

        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    header: true,
                    items: SpacesNavigator
                        .parameters(model)
                        .components
                        .flatMap { $0.items }
                ),
            ]
        )
    }
}

struct SheetsNavigator: Mapper {
    static func controls(_ model: any Model) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.active == ref || model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Sheet.Type else { return }
                model.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, _ in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                return AnyView(
                    Button {
                        model.session.close(ref)
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 18, height: 18, alignment: .center)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.tertiary.opacity(0.3))
                            )
                    }
                        .buttonStyle(.plain)
                        .help("Close")
                )
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var order: [Reference: Int] = [:]
        for (index, ref) in model.session.opened.sheets.enumerated() {
            order[ref] = index
        }

        func position(_ item: ItemParams) -> Int {
            guard let ref = item.ref else { return .max }
            return order[ref] ?? .max
        }

        let items = model.session.opened.sheets.compactMap { ref -> ItemParams? in
            guard ref.type is Sheet.Type else { return nil }
            return .init(
                ref: ref,
                name: ref.descriptor.name,
                image: Iconography.icon(for: ref).symbol
            )
        }.sorted {
            let lhs = position($0)
            let rhs = position($1)
            if lhs != rhs { return lhs < rhs }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct StudioLibraryMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func sort(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        func items<T: Resolvable>(for type: T.Type, image: String) -> [ItemParams] {
            sort(Runtime.shared.all(as: type).compactMap { (ref, entry) in ItemParams(ref: ref, name: entry.name, image: image) })
        }

        return .init(
            nesting: .recursive,
            header: false,
            components: [
                .init(
                    id: "favorites",
                    header: false,
                    items: [
                        .init(
                            name: "Inbox",
                            image: "tray"
                        ),
                        .init(
                            name: "Drafts",
                            image: "square.and.pencil"
                        ),
                        .init(
                            name: "Scheduled",
                            image: "clock"
                        ),
                    ]
                ),
                .init(
                    id: "library",
                    name: "Library",
                    header: true,
                    items: [
                        .init(
                            name: "Apps",
                            image: "square.grid.3x3.square"
                        ),
                        .init(
                            name: "Bookmarks",
                            image: "bookmark"
                        ),
                        .init(
                            name: "Commands",
                            image: "switch.2"
                        ),
                        .init(
                            name: "Harnesses",
                            image: "brain.head.profile"
                        ),
                        .init(
                            name: "Skills",
                            image: "text.alignleft"
                        ),
                    ]
                ),
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: true,
                    items: SpacesNavigator
                        .parameters(model)
                        .components
                        .flatMap { $0.items }
                ),
            ]
        )
    }
}

struct SheetInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
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

        guard case .content(let sheet) = model.session.focused, sheet.type is Sheet.Type
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
