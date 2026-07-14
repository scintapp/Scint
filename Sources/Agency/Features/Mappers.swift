import AgencyRuntime
import SwiftUI


struct EmptyMap: Mapper {}

struct SheetMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        .init()
    }
}

struct BrowserMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused == .structure(ref)
                || agency.session.focused == .interface(ref)
                || agency.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { agency.select(ref) }
                else { agency.open(ref) }
            },
            surfaceActions: {
                guard let owner = agency.session.selected.space else { return [] }
                return Action.surfaceItems(for: owner)
            },
            surfaceDropTarget: {
                agency.session.selected.space.map { .init(ref: $0, name: $0.descriptor.name) }
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        guard let ref = agency.session.selected.space else { return DashboardMap.parameters(agency) }
        let closure = Space.with(ref, { $0.closure })
        let content = closure.flatMap { Closure.with($0, { $0.content }) } ?? []
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

        let contentItems: [ItemParams] = content.map { ref in
                .init(
                    ref: ref,
                    origin: ref,
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
                    items: spaceItems + contentItems.filter { $0.ref?.type == Sheet.self && $0.name != "Input" }
                ),
            ]
        )
    }
}

struct DashboardMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused == .structure(ref)
                || agency.session.focused == .interface(ref)
                || agency.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { agency.select(ref) }
                else { agency.open(ref) }
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let spaces = Workspace.with(agency.session.workspace, { $0.spaces }) ?? []
        let closure = Workspace.with(agency.session.workspace, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { space in
                return .init(
                    ref: space,
                    origin: agency.session.workspace,
                    name: space.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
                .init(
                    ref: ref,
                    origin: agency.session.workspace,
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

struct MenuMap: Mapper {
    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.studio.actions.query
        let components = Runtime.shared.search("\(query) !components", limit: 8).all
        let controls = Runtime.shared.search("\(query) !control", limit: 8).all
        let services = Runtime.shared.search("\(query) !service", limit: 8).all
        let spaces = Runtime.shared.search("\(query) !space",  limit: 8).all

        return .init(
            nesting: .flat,
            components: [
                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
            ]
        )
    }
}

struct SearchMap: Mapper {
    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.studio.actions.query
        let components = agency.search("\(query) !components", limit: 20).all
        let controls = Runtime.shared.search("\(query) !control", limit: 20).all
        let services = Runtime.shared.search("\(query) !service", limit: 20).all
        let spaces = Runtime.shared.search("\(query) !space",  limit: 20).all

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "components",
                    name: "Sheets",
                    header: false,
                    image: "text.alignleft",
                    items: components.map(item(from:))
                ),
                .init(
                    id: "controls",
                    name: "Controls",
                    header: false,
                    image: "switch.2",
                    items: controls.map(item(from:))
                ),
                .init(
                    id: "services",
                    name: "Harness",
                    header: false,
                    image: "arrow.2.squarepath",
                    items: services.map(item(from:))
                ),
                .init(
                    id: "spaces",
                    name: "Workspaces",
                    header: false,
                    image: "cube.transparent",
                    items: spaces.map(item(from:))
                )
            ]
        )
    }
}

struct ContentMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        func selected(_ item: ItemParams) -> Bool {
            guard let ref = item.ref else { return false }
            if let url = item.path { return agency.session.selected.selected(ref, url) }
            return agency.session.selected.selected(ref)
        }

        func select(_ item: ItemParams) {
            guard let ref = item.ref else { return }
            agency.select(ref)
        }

        return .init(
            selected: selected,
            onSelect: select,
            itemActions: { item in item.path == nil ? Action.itemItems(for: item) : [] },
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let owner = agency.session.selected.space ?? agency.session.workspace
        let closure = Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

        func items(image: String) -> [ItemParams] {
            sortItems(sheets.compactMap { ref in
                guard ref.type is Sheet.Type else { return nil }
                return .init(
                    ref: ref,
                    origin: owner,
                    name: ref.descriptor.name,
                    image: image
                )
            })
        }

        return .init(
            nesting: .recursive,
            header: false,
            components: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: false,
                    items: items(image: "text.alignleft")
                ),
            ],
        )
    }
}

struct PreviewMap: Mapper {
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

struct TranscriptsMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        .init()
    }
}

struct LibraryMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
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
                    id: "library",
                    name: "Library",
                    header: true,
                    items: [
                        .init(
                            name: "Apps",
                            image: "square.grid.2x2.fill"
                        ),
                        .init(
                            name: "Commands",
                            image: "switch.2"
                        ),
                        .init(
                            name: "Harnesses",
                            image: "gear"
                        ),
                        .init(
                            name: "Skills",
                            image: "brain.head.profile"
                        )
                    ]
                ),
                .init(
                    id: "resources",
                    name: "Resources",
                    header: true,
                    items: [
                        .init(
                            name: "Bookmarks",
                            image: "bookmark"
                        ),
                        .init(
                            name: "Scripts",
                            image: "scroll"
                        ),
                        .init(
                            name: "Templates",
                            image: "text.alignleft"
                        )
                    ]
                )
            ]
        )
    }
}

struct SheetsMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.active == ref || agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Sheet.Type else { return }
                agency.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, _ in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                return AnyView(
                    Button {
                        agency.session.close(ref)
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

    static func parameters(_ agency: AgencyModel) -> Params {
        var order: [Reference: Int] = [:]
        for (index, ref) in agency.session.opened.sheets.enumerated() {
            order[ref] = index
        }

        func position(_ item: ItemParams) -> Int {
            guard let ref = item.ref else { return .max }
            return order[ref] ?? .max
        }

        let items = agency.session.opened.sheets.compactMap { ref -> ItemParams? in
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

struct DirectoryMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let expanded = agency.studio.navigator.state.expanded

        func sortFileItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.path.map { agency.artifacts.directory(at: $0) } ?? false
                let rhsDirectory = $1.path.map { agency.artifacts.directory(at: $0) } ?? false
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Handle, root: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let children: [ItemParams] = (entry.directory && expanded.contains(AnyHashable(url)))
            ? sortFileItems(agency.artifacts.children(for: entry).compactMap { file(for: .file($0), root: root, in: agency) })
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

        func folder(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.handle }), let url = entry.url else { return nil }
            let isDirectory = entry.directory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = (isDirectory && isExpanded)
            ? sortFileItems(agency.artifacts.children(for: entry).compactMap { file(for: .file($0), root: ref, in: agency) })
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
                    items: sortFileItems(agency.artifacts.artifacts.compactMap { folder(for: $0, in: agency) })
                )
            ]
        )
    }
}

struct SpacesMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
                agency.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Space.Type
                let rhsBoundary = $1.ref?.type is Space.Type
                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func space(for ref: Reference, owner: Reference, in agency: AgencyModel) -> ItemParams {
            let spaces = Space.with(ref, { $0.spaces.map { space(for: $0, owner: ref, in: agency) }}) ?? []

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
                    name: "Workspace",
                    items: sorted(Workspace.with(agency.session.workspace, {
                        $0.spaces.map { space(for: $0, owner: agency.session.workspace, in: agency) } }) ?? [])
                )
            ]
        )
    }
}

struct NavigatorMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        let sheets = SheetsMap.controls(agency)

        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Sheet.Type { return sheets.selected?(item) ?? false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
                agency.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
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

    static func parameters(_ agency: AgencyModel) -> Params {
        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: true,
                    items: SheetsMap
                        .parameters(agency)
                        .components
                        .flatMap { $0.items }
                ),
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: true,
                    items: SpacesMap
                        .parameters(agency)
                        .components
                        .flatMap { $0.items }
                )
            ]
        )
    }
}

struct ComponentsMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.panels.query
        let sheets = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Sheet.Type }
        let transcripts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Transcript.Type }

        return .init(
            nesting: .flat,
            components: [
                .init(id: "sheets", name: "Sheets", items: sheets.map(item(from:))),
                .init(id: "transcripts", name: "Transcripts", items: transcripts.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct InterfacesMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.panels.query
        let artifacts = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Artifact.Type }
        let controls = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Command.Type }
        let services = Runtime.shared.search(query, limit: 50).all.filter { $0.ref.type is Harness.Type }

        return .init(
            nesting: .flat,
            components: [
                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
                .init(id: "controls", name: "Controls", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", items: services.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct StructuresMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let query = agency.panels.query
        let results = Runtime.shared.search(query, limit: 50).all.filter {
            $0.ref.type is Space.Type
        }

        return .init(
            nesting: .flat,
            components: [
                .init(
                    id: "space",
                    name: "Space",
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct SpaceSettingsMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        var space: Reference {
            if case .structure(let ref) = agency.session.focused { return ref }
            else { return agency.session.space ?? agency.session.workspace }
        }

        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })

        return .init(
            onSelect: { item in
                guard let ref = item.ref, let closure, !item.active else { return }
                Closure.update(closure) { $0.interfaces.append(ref) }
            },
            onAction: { item in
                guard let harness = item.ref else { return }
                if space.type is Workspace.Type { Workspace.update(space) { $0.harness = harness } }
                else { Space.update(space) { $0.harness = harness } }
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        var space: Reference {
            if case .structure(let ref) = agency.session.focused { return ref }
            else { return agency.session.space ?? agency.session.workspace }
        }

        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })
        let harnesses = closure.flatMap { Closure.with($0, { $0.harnesses }) } ?? []
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

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: [
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
        )
    }
}

struct SheetOutlineMap: Mapper {
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
