import AgencyRuntime
import AppKit
import SwiftUI


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
        guard let space = agency.session.selected.space else { return DashboardMap.parameters(agency) }
        let closure = Space.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []
        let spaces = Space.with(space, { $0.spaces }) ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { child in
                return .init(
                    ref: child,
                    origin: space,
                    name: child.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
                .init(
                    ref: ref,
                    origin: space,
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
                    items: spaceItems + stateItems
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
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []

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
                    items: spaceItems + stateItems
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

struct ComposerMap: Mapper {}

struct EmptyMap: Mapper {}

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

struct SpaceSettingsMap: Mapper {
    private static let pickerLimit = 500

    private static func selectedSpace(_ agency: AgencyModel) -> Reference {
        switch agency.session.focused {
            case .structure(let focused): return focused
            default: return agency.session.selected.structure ?? agency.session.workspace
        }
    }

    private static func closure(for owner: Reference) -> Reference? {
        Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
    }

    @discardableResult
    private static func attach(_ ref: Reference, to owner: Reference) -> Bool {
        guard ref != owner else { return false }

        if owner.type is Harness.Type, ref.type is Command.Type {
            return Harness.update(owner) { $0.command = ref } != nil
        }

        if ref.type is Harness.Type {
            if owner.type is Workspace.Type { return Workspace.update(owner) { $0.harness = ref } != nil }
            return Space.update(owner) { $0.harness = ref } != nil
        }

        if ref.type is Space.Type {
            guard !contains(ref, owner), let space = Space.with(ref, { $0 }) else { return false }
            space.attach(to: owner)
            return true
        }

        guard let closure = closure(for: owner) else { return false }

        if ref.type is Sheet.Type {
            let changed = Closure.update(closure) { bound -> Bool in
                guard !bound.state.contains(ref) else { return false }
                bound.state.append(ref)
                return true
            } ?? false
            if changed { Sheet.update(ref) { $0.owner = closure } }
            return changed
        }

        if ref.type is Transcript.Type || ref.type is any Functional.Type {
            return Closure.update(closure) { bound -> Bool in
                guard !bound.components.contains(ref) else { return false }
                bound.components.append(ref)
                return true
            } ?? false
        }

        return false
    }

    private static func contains(_ child: Reference, _ parent: Reference) -> Bool {
        var cursor: Reference? = parent
        while let current = cursor {
            if current == child { return true }
            cursor = Space.with(current) { $0.space } ?? nil
        }
        return false
    }

    private static func modalityLabel(_ modality: Harness.Modality?) -> String {
        switch modality {
            case .compose: return "Compose"
            case .dispatch: return "Dispatch"
            case .observe: return "Observe"
            case .execute: return "Execute"
            case .traverse: return "Traverse"
            case nil: return "Configure"
        }
    }

    private static func parameterName(_ parameter: Harness.Parameter) -> String {
        switch parameter {
            case .argument(let content, _, _, _): return content
            case .command(let content, _): return content
            case .dependency(let name, _, _): return name
            case .requirement(let name, _, _): return name
            case .target(let name, _): return name
        }
    }

    private static func harnessDescription(_ ref: Reference) -> String {
        Harness.with(ref) { harness in
            let mode = modalityLabel(harness.modality)
            let command = Command.with(harness.command) { $0.ref.descriptor.name } ?? ""
            return command.isEmpty ? "\(mode) harness" : "\(mode) harness using \(command)"
        } ?? ""
    }

    private static func pickerItems(
        _ agency: AgencyModel,
        query: String,
        owner: Reference,
        active: Set<Reference>,
        tint: Color? = nil,
        matches: (Reference) -> Bool
    ) -> [ItemParams] {
        agency.search(query, limit: pickerLimit).all
            .compactMap { result -> ItemParams? in
                guard matches(result.ref) else { return nil }
                let description = result.description.isEmpty && result.ref.type is Harness.Type
                    ? harnessDescription(result.ref)
                    : result.description

                return .init(
                    ref: result.ref,
                    origin: owner,
                    name: result.name,
                    image: Iconography.icon(for: result.ref).symbol,
                    tint: tint,
                    description: description,
                    active: active.contains(result.ref)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

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
                if let owner = item.origin, !item.active, attach(ref, to: owner) {
                    agency.focus(ref)
                    Task { try? await Runtime.shared.save() }
                    return
                }

                if ref.type is Workspace.Type || ref.type is Space.Type { agency.select(ref) }
                else { agency.focus(ref) }
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.open(ref)
            },
            onAction: { _ in
                let origin = selectedSpace(agency)

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
                let ref = selectedSpace(agency)
                return Action.surfaceItems(for: ref)
            },
            surfaceDropTarget: {
                let ref = selectedSpace(agency)
                return .init(ref: ref, name: ref.descriptor.name)
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let space = selectedSpace(agency)
        let workspaceHarness = Workspace.with(space) { workspace in
            Harness.with(workspace.harness, { _ in workspace.harness })
        }.flatMap { $0 }
        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []
        let spaceHarness = Space.with(space, { $0.harness }).flatMap { $0 }
        let harness = spaceHarness ?? workspaceHarness
        let command = harness.flatMap { Harness.with($0, { $0.command }) }
        let modality = harness.flatMap { Harness.with($0, { $0.modality }) }
        let parameters = harness.flatMap { Harness.with($0, { $0.parameters }) } ?? []
        let sheets = Set(state.filter { $0.type is Sheet.Type })
        let childSpaces = Space.with(space, { $0.spaces }) ?? Workspace.with(space, { $0.spaces }) ?? []
        let process = agency.session.context
        let eventCount = process.flatMap { Transcript.with($0.transcript, { $0.entries.count }) } ?? 0

        let allHarnesses = pickerItems(
            agency,
            query: "!harness",
            owner: space,
            active: Set(harness.map { [$0] } ?? []),
            tint: Design.Tint.harness
        ) { $0.type is Harness.Type }

        let harnessRows = allHarnesses.map { item in
            ItemParams(
                ref: item.ref,
                origin: item.origin,
                name: item.name,
                image: item.image,
                tint: item.tint,
                trailingKind: .value,
                value: item.active ? "Active" : "Enable",
                description: item.description,
                active: item.active
            )
        }

        let harnesses = ComponentParams(
            id: "harnesses",
            name: "Harnesses",
            header: true,
            items: [
                .init(
                name: "Add Harness...",
                image: "command",
                trailingKind: .load,
                items: allHarnesses
            )] + harnessRows
        )

        let commandItems = harness.map {
            pickerItems(
                agency,
                query: "!command",
                owner: $0,
                active: Set(command.map { [$0] } ?? []),
                tint: Design.Tint.command
            ) { $0.type is Command.Type }
        } ?? []

        let parameterSummary = parameters.map(parameterName).prefix(3).joined(separator: ", ")
        let settings = ComponentParams(
            id: "settings",
            name: "Settings",
            header: true,
            items: [
                .init(
                    name: "Command Binding",
                    image: "command",
                    trailingKind: .load,
                    count: command == nil ? 0 : 1,
                    description: command?.descriptor.name ?? "No command bound",
                    items: commandItems
                ),
                .init(
                    name: "Parameters",
                    image: "slider.horizontal.3",
                    trailingKind: .value,
                    count: parameters.count,
                    value: "\(parameters.count)",
                    description: parameterSummary.isEmpty ? "No configured parameters" : parameterSummary
                ),
                .init(
                    name: "Configure \(modalityLabel(modality))",
                    image: "target",
                    trailingKind: .value,
                    value: "...",
                    description: "Target, signal source, and transcript output"
                )
            ]
        )

        let sheetItems = pickerItems(
            agency,
            query: "!sheet",
            owner: space,
            active: sheets,
            tint: Design.Tint.sheet
        ) { $0.type is Sheet.Type }

        let spaceItems = pickerItems(
            agency,
            query: "!space",
            owner: space,
            active: childSpaces,
            tint: Design.Tint.space
        ) { $0.type is Space.Type && $0 != space }

        let activity: String = switch process?.state {
            case .running, .active: "Watching"
            case .blocked: "Blocked"
            case .failed: "Failed"
            case .idle: "Idle"
            case nil: "Idle"
        }

        let contextSection = ComponentParams(
            id: "context",
            name: "Context",
            header: true,
            items: [
                .init(
                    name: "Transcripts",
                    image: "text.bubble",
                    trailingKind: .value,
                    value: eventCount == 1 ? "1 event" : "\(eventCount) events",
                    description: "Root transcript and \(modalityLabel(modality)) branch"
                ),
                .init(
                    name: "Sheets",
                    image: "doc.text",
                    trailingKind: .load,
                    count: sheets.count,
                    description: "Documents available to the harness",
                    items: sheetItems
                ),
                .init(
                    name: "Spaces",
                    image: "point.3.connected.trianglepath.dotted",
                    trailingKind: .load,
                    count: childSpaces.count,
                    description: "Child boundaries enclosed here",
                    items: spaceItems
                ),
                .init(
                    name: "Process Activity",
                    image: "waveform.path.ecg",
                    trailingKind: .value,
                    value: activity,
                    description: process == nil ? "No composed context for this space" : "Context exists for this space"
                )
            ]
        )

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: [
                contextSection,
                harnesses,
                settings
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

struct SettingsMap: Mapper {
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

    static func parameters(_ agency: AgencyModel) -> Params {
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

struct DirectoryMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
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

struct SheetOutlineMap: Mapper {
    private struct OutlineSummary {
        var blocks = 0
        var artifacts = 0
        var commands = 0
        var sheets = 0
        var tasks = 0
        var pendingTasks = 0
    }

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
        func currentSheet() -> Reference? {
            if case .content(let ref) = agency.session.focused, ref.type is Sheet.Type { return ref }
            if let ref = agency.session.selected.content, ref.type is Sheet.Type { return ref }
            return agency.session.active
        }

        func preview(_ text: String, lines: Int = 1) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = trimmed
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(lines)
                .joined(separator: "\n")
            return result.isEmpty ? trimmed : result
        }

        func contentKind(_ text: String) -> (image: String, tint: Color, description: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("# ") { return ("textformat.size", Design.Tint.info, "Document heading") }
            if trimmed.hasPrefix("## ") { return ("textformat", Design.Tint.info, "Section heading") }
            if trimmed.hasPrefix("### ") { return ("textformat", Design.Tint.info, "Subsection heading") }
            return ("line.3.horizontal", Design.Tint.inactive, "Paragraph")
        }

        func displayText(_ text: String) -> String {
            let trimmed = preview(text)
            if trimmed.hasPrefix("### ") { return String(trimmed.dropFirst(4)) }
            if trimmed.hasPrefix("## ") { return String(trimmed.dropFirst(3)) }
            if trimmed.hasPrefix("# ") { return String(trimmed.dropFirst(2)) }
            return trimmed
        }

        func firstParagraph(in blocks: [Sheet.Block]) -> String {
            for block in blocks {
                switch block {
                    case .content(_, let text):
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.hasPrefix("#") else { continue }
                        let paragraphs = trimmed.components(separatedBy: "\n\n")
                        if let paragraph = paragraphs
                            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                            .first(where: { !$0.isEmpty }) {
                            return preview(paragraph, lines: 3)
                        }
                    case .sheet(let ref):
                        let nested = Sheet.with(ref) { firstParagraph(in: $0.blocks) } ?? ""
                        if !nested.isEmpty { return nested }
                    default:
                        continue
                }
            }
            return ""
        }

        func commandDescription(_ ref: Reference) -> String {
            Command.with(ref) { command in
                command.rendered.prefix(3).joined(separator: " ")
            } ?? ""
        }

        func artifactDescription(_ ref: Reference) -> String {
            Artifact.with(ref) { artifact in
                switch artifact.handle {
                    case .http(let url): return url?.host() ?? "Web link"
                    case .app: return "Application"
                    case .file(let url), .image(let url), .script(let url), .skill(let url), .exec(let url):
                        return url?.isFileURL == true ? "Local file" : artifact.handle.name
                }
            } ?? ""
        }

        func summarize(_ blocks: [Sheet.Block]) -> OutlineSummary {
            var summary = OutlineSummary()
            for block in blocks {
                summary.blocks += 1
                switch block {
                    case .artifact:
                        summary.artifacts += 1
                    case .command:
                        summary.commands += 1
                    case .sheet(let ref):
                        summary.sheets += 1
                        let nested = Sheet.with(ref) { summarize($0.blocks) } ?? OutlineSummary()
                        summary.blocks += nested.blocks
                        summary.artifacts += nested.artifacts
                        summary.commands += nested.commands
                        summary.sheets += nested.sheets
                        summary.tasks += nested.tasks
                        summary.pendingTasks += nested.pendingTasks
                    case .task(_, _, let done):
                        summary.tasks += 1
                        if !done { summary.pendingTasks += 1 }
                    case .content:
                        break
                }
            }
            return summary
        }

        func sheetDescription(_ ref: Reference) -> String {
            let summary = Sheet.with(ref) { summarize($0.blocks) } ?? OutlineSummary()
            let taskSummary = "\(summary.tasks - summary.pendingTasks)/\(summary.tasks) tasks"
            let artifactSummary = summary.artifacts == 1 ? "1 artifact" : "\(summary.artifacts) artifacts"
            return "\(summary.blocks) blocks · \(taskSummary) · \(artifactSummary)"
        }

        func item(for block: Sheet.Block, owner: Reference) -> ItemParams {
            switch block {
                case .artifact(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: Iconography.icon(for: ref).symbol,
                        tint: Iconography.icon(for: ref).tint,
                        description: artifactDescription(ref)
                    )
                case .command(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: Iconography.icon(for: ref).symbol,
                        tint: Iconography.icon(for: ref).tint,
                        description: commandDescription(ref)
                    )
                case .content(let id, let text):
                    let kind = contentKind(text)
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: displayText(text),
                        image: kind.image,
                        tint: kind.tint,
                        description: kind.description
                    )
                case .sheet(let ref):
                    let children = Sheet.with(ref, { sheet in
                        sheet.blocks.map { item(for: $0, owner: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: Iconography.icon(for: ref).symbol,
                        tint: Iconography.icon(for: ref).tint,
                        description: sheetDescription(ref),
                        items: children
                    )
                case .task(let id, let title, let done):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: preview(title),
                        image: done ? "checkmark.square" : "square",
                        tint: Design.Tint.task,
                        description: done ? "Completed task" : "Open task"
                    )
            }
        }

        let sheet = currentSheet()
        let items: [ItemParams]
        let blocks: [Sheet.Block]
        if let ref = sheet {
            items = Sheet.with(ref, { sheet in
                sheet.blocks.map { item(for: $0, owner: ref) }
            }) ?? []
            blocks = Sheet.with(ref, { $0.blocks }) ?? []
        } else {
            items = []
            blocks = []
        }

        let summary = summarize(blocks)
        let context = ComponentParams(
            id: "context",
            name: "Context",
            header: true,
            footer: "Context can become a compact runtime summary: loaded material, unresolved inputs, active tools, and agent-visible constraints.",
            items: [
                .init(
                    name: "Blocks",
                    image: "list.bullet.rectangle",
                    trailingKind: .value,
                    value: "\(summary.blocks) blocks",
                    description: "Total visible document structure"
                ),
                .init(
                    name: "Artifacts",
                    image: "doc.on.doc",
                    trailingKind: .value,
                    value: "\(summary.artifacts) loaded",
                    description: "Links and local files in scope"
                ),
                .init(
                    name: "Commands",
                    image: "terminal",
                    trailingKind: .value,
                    value: "\(summary.commands) active",
                    description: "Inline tools available to agents"
                ),
                .init(
                    name: "Sheets",
                    image: "doc.text",
                    trailingKind: .value,
                    value: "\(summary.sheets) loaded",
                    description: "Included as runnable context"
                ),
                .init(
                    name: "Tasks",
                    image: "checklist",
                    trailingKind: .value,
                    value: "\(summary.pendingTasks) pending",
                    description: "Open operator handoffs"
                )
            ]
        )

        return .init(
            ref: sheet,
            name: sheet?.descriptor.name ?? "",
            description: sheet.map { _ in firstParagraph(in: blocks) } ?? "",
            layout: .group,
            nesting: .recursive,
            header: true,
            components: [
                context,
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

struct OutlineMap: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
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

    static func parameters(_ agency: AgencyModel) -> Params {
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

//struct MenuMap: Mapper {
//    static func controls(_ agency: AgencyModel) -> Controls {
//        .init()
//    }
//
//    static func parameters(_ agency: AgencyModel) -> PanelParams {
//        let query = agency.panels.query
//        let components = Runtime.shared.search("\(query) !components", limit: 8).all
//        let controls = Runtime.shared.search("\(query) !control", limit: 8).all
//        let services = Runtime.shared.search("\(query) !service", limit: 8).all
//        let spaces = Runtime.shared.search("\(query) !space",  limit: 8).all
//
//        return .init(
//            nesting: .flat,
//            components: [
//                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
//                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
//                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
//                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
//            ]
//        )
//    }
//}
//
//struct SearchMap: Mapper {
//    static func controls(_ agency: AgencyModel) -> Controls {
//        .init()
//    }
//
//    static func parameters(_ agency: AgencyModel) -> PanelParams {
//        let query = agency.panels.query
//        let components = agency.search("\(query) !components", limit: 20).all
//        let controls = Runtime.shared.search("\(query) !control", limit: 20).all
//        let services = Runtime.shared.search("\(query) !service", limit: 20).all
//        let spaces = Runtime.shared.search("\(query) !space",  limit: 20).all
//
//        return .init(
//            nesting: .flat,
//            components: [
//                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
//                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
//                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
//                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
//            ]
//        )
//    }
//}
