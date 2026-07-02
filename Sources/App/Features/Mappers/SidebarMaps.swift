import AppKit
import SwiftUI
import AgencyRuntime

struct ComposerMap: Mapper {}

struct ContentMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        func selected(_ item: ItemParams) -> Bool {
            guard let ref = item.ref else { return false }
            if let url = item.path { return agency.session.selected.selected(ref, url) }
            return agency.session.selected.selected(ref)
        }

        func select(_ item: ItemParams) {
            guard let ref = item.ref else { return }
            if ref.type is Sheet.Type {
                agency.select(ref)
                agency.open(ref)
                return
            }
            agency.select(ref)
        }

        return .init(
            selected: selected,
            onSelect: select,
            itemActions: { item in item.path == nil ? Action.itemItems(for: item) : [] },
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let owner = agency.session.selected.space ?? agency.session.workspace
        let closure = Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.state }) } ?? []

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
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
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
                agency.select(ref)
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

    static func parameters(_ studio: AgencyModel, _ panel: any Panel) -> PanelParams {
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

struct SettingsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
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
                agency.select(ref)
                agency.open(ref)
            },
            onAction: { _ in
                let origin: Reference
                switch agency.session.focused {
                    case .structure(let focused): origin = focused
                    default: origin = agency.session.selected.structure!
                }

                func add(_ ref: Reference, to origin: Reference) {
                    if origin.type is Workspace.Type { Workspace.with(origin, { $0.add(ref: ref) }) }
                    else { Space.with(origin, { $0.add(ref: ref) }) }
                }

                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.canCreateDirectories = false
                panel.resolvesAliases = true
                panel.title = "Choose Files or Folders"
                panel.prompt = "Load"

                guard panel.runModal() == .OK else { return }

                for url in panel.urls {
                    let ref = Artifact.register(url.lastPathComponent, url)
                    add(ref, to: origin)
                }

                Task { try? await Runtime.shared.save() }
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        let space: Reference
        switch agency.session.focused {
            case .structure(let focused): space = focused
            default: space = agency.session.selected.structure!
        }

        let workspaceHarness = Workspace.with(space, { workspace in Harness.with(workspace.harness, { _ in workspace.harness }) }).flatMap { $0 }
        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []
        let components = closure.flatMap { Closure.with($0, { $0.components }) } ?? []
        let spaceHarness = Space.with(space, { $0.harness }).flatMap { $0 }
        let harness = spaceHarness ?? workspaceHarness
        let commands = components.filter { $0.type is Command.Type }

        let files = components.filter { ref in
            Artifact.with(ref) { artifact in
                switch artifact.handle {
                    case .http: return false
                    case .app, .file, .image, .script, .skill, .exec: return true
                }
            } ?? false
        }

        func items(_ refs: [Reference], image: String, tint: Color) -> [ItemParams] {
            refs
                .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
                .map {
                    .init(
                        ref: $0,
                        name: $0.descriptor.name,
                        image: image,
                        tint: tint
                    )
                }
        }

        let sheets = state.filter { $0.type is Sheet.Type }

        let automations = ComponentParams(
            id: "automations",
            name: "Automations",
            header: false,
            footer: "Automate when and how often this space runs.",
            items: [
                .init(name: "Date", image: "calendar", trailingKind: .toggle),
                .init(name: "Time", image: "clock", trailingKind: .toggle),
                .init(name: "Repeat", image: "repeat", trailingKind: .toggle),
            ]
        )

        let fileItems = ItemParams(
            name: "Files and Folders",
            image: "folder",
            trailingKind: .action,
            count: files.count
        )
        let sheetItems = ItemParams(
            name: "Sheets",
            image: "text.alignleft",
            trailingKind: .load,
            count: sheets.count,
            items: items(sheets, image: "text.alignleft", tint: Design.Tint.sheet)
        )
        let context = ComponentParams(
            id: "context",
            name: "Context",
            header: false,
            footer: "Build context with files, folders, and Sheets.",
            items: [fileItems, sheetItems]
        )

        let harnessItems = ItemParams(
            name: "Harness",
            image: "arrow.2.squarepath",
            trailingKind: .load,
            count: harness == nil ? 0 : 1,
            description: harness.map { Runtime.shared.get($0).name } ?? "None",
            items: harness.map { items([$0], image: "arrow.2.squarepath", tint: Design.Tint.harness) } ?? []
        )
        let commandItems = ItemParams(
            name: "Commands",
            image: "switch.2",
            trailingKind: .load,
            count: commands.count,
            items: items(commands, image: "switch.2", tint: Design.Tint.command)
        )
        let tooling = ComponentParams(
            id: "tooling",
            name: "Tooling",
            header: false,
            footer: "Select a harness and add commands.",
            items: [harnessItems, commandItems]
        )

        return .init(
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: [automations, context, tooling]
        )
    }
}

struct TranscriptsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        .init()
    }
}

struct LibraryMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is Sheet.Type {
                    agency.select(ref)
                    agency.open(ref)
                    return
                }
                agency.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
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

struct DirectoryMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        return Controls(
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        let expanded = agency.studio.navigator.expanded

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
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
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
                if ref.type is Workspace.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .workspace
                } else if ref.type is Space.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .space
                }
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
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

struct SheetsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.active == ref || agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Sheet.Type else { return }
                agency.select(ref)
                agency.open(ref)
                agency.focus(ref)
                agency.studio.detail.model = .editor
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
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

struct NavigatorMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        let sheets = SheetsMap.controls(agency, panel)

        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Sheet.Type { return sheets.selected?(item) ?? false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is Sheet.Type {
                    sheets.onSelect?(item)
                    return
                }
                agency.select(ref, entry: item.entryId, url: item.path)
                agency.focus(ref)
                if ref.type is Workspace.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .workspace
                } else if ref.type is Space.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .space
                }
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: true,
                    items: SheetsMap
                        .parameters(agency, panel)
                        .components
                        .flatMap { $0.items }
                ),
                .init(
                    id: "spaces",
                    name: "Spaces",
                    header: true,
                    items: SpacesMap
                        .parameters(agency, panel)
                        .components
                        .flatMap { $0.items }
                )
            ]
        )
    }
}

struct OutlineMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        return .init(
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        func preview(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? trimmed
        }

        func item(for block: Sheet.Block, owner: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block, size: 13)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint
                    )
                case .content(let id, let text):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: preview(text),
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
                        items: children
                    )
                case .task(let id, let title, _):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: preview(title),
                        image: icon.symbol,
                        tint: icon.tint
                    )
            }
        }

        let items: [ItemParams]
        if case .content(let ref) = agency.session.focused {
            items = Sheet.with(ref, { sheet in
                sheet.blocks.map { item(for: $0, owner: ref) }
            }) ?? []
        } else {
            items = []
        }

        return .init(
            layout: .list,
            nesting: .recursive,
            components: [
                .init(
                    id: "outline",
                    name: "Outline",
                    header: false,
                    items: items
                )
            ]
        )
    }
}
