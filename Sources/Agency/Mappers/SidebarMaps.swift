import AppKit
import SwiftUI
import AgencyRuntime

struct PreviewMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref) || agency.session.isFocused(ref)
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
                Action.surfaceItems(for: agency.session.inspectingSpace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.inspectingSpace, name: agency.session.inspectingSpace.descriptor.name)
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }


    static func parameters(_ studio: AgencyModel, _ panel: any Panel) -> Parameters {
        .init(
            sections: [
                .init(
                    id: "context",
                    name: "Context",
                    layout: .group,
                    footnote: "A preview of this space's context, as the agent or model sees it.",
                    body: ""
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    layout: .group,
                    footnote: "An estimate of the tokens required to process this space.",
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
            onSelect: { item in
                let origin = agency.session.inspectingSpace
                guard let ref = item.ref else { return }
                add(ref, to: origin)
                return
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        let space = agency.session.inspectingSpace

        let workspaceHarness = Workspace.with(space, { workspace in
            Harness.with(workspace.harness, { _ in
                workspace.harness })
        }).flatMap { $0 }

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

        func active(_ ref: Reference) -> Bool {
            switch ref.type {
                case is Harness.Type: harness == ref
                case is Sheet.Type, is Transcript.Type: state.contains(ref)
                case is Command.Type, is Artifact.Type: components.contains(ref)
                default: state.contains(ref) || components.contains(ref)
            }
        }

        func libraryItems<T: Resolvable>(_ type: T.Type, image: String, tint: Color) -> [ItemParams] {
            Runtime.shared.all(as: type)
                .sorted { $0.1.name.localizedCaseInsensitiveCompare($1.1.name) == .orderedAscending }
                .map { ref, entry in
                        .init(
                            ref: ref,
                            name: entry.name,
                            image: image,
                            tint: tint,
                            active: active(ref)
                        )
                }
        }

        return .init(
            header: true,
            sections: [
                .init(
                    id: "automations",
                    name: "Automations",
                    layout: .group,
                    footnote: "Automate when and how often this space runs.",
                    items: [
                        .init(name: "Date", image: "calendar", trailingKind: .toggle),
                        .init(name: "Time", image: "clock", trailingKind: .toggle),
                        .init(name: "Repeat", image: "repeat", trailingKind: .toggle),
                    ]
                ),
                .init(
                    id: "context",
                    name: "Context",
                    layout: .group,
                    footnote: "Build context with files, folders, and Sheets.",
                    items: [
                        .init(
                            name: "Files and Folders",
                            image: "folder",
                            trailingKind: .action,
                            count: files.count,
                        ),
                        .init(
                            name: "Sheets",
                            image: "text.alignleft",
                            trailingKind: .load,
                            count: state.filter { $0.type is Sheet.Type }.count,
                            items: libraryItems(Sheet.self, image: "text.alignleft", tint: Design.Tint.sheet)
                        ),
                    ]
                ),
                .init(
                    id: "tooling",
                    name: "Tooling",
                    layout: .group,
                    footnote: "Select a harness and add commands.",
                    items: [
                        .init(
                            name: "Harness",
                            image: "arrow.2.squarepath",
                            trailingKind: .load,
                            count: harness == nil ? 0 : 1,
                            description: harness.map { Runtime.shared.get($0).name } ?? "None",
                            items: libraryItems(Harness.self, image: "arrow.2.squarepath", tint: Design.Tint.harness)
                        ),
                        .init(
                            name: "Commands",
                            image: "switch.2",
                            trailingKind: .load,
                            count: commands.count,
                            items: libraryItems(Command.self, image: "switch.2", tint: Design.Tint.command)
                        )
                    ]
                ),
            ]
        )
    }

    private static func add(_ ref: Reference, to origin: Reference) {
        if origin.type is Workspace.Type { Workspace.with(origin, { $0.add(ref: ref) }) }
        else { Space.with(origin, { $0.add(ref: ref) }) }
    }

    private static func chooseFiles(to origin: Reference) {
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        func sortItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func items<T: Resolvable>(for type: T.Type, image: String) -> [ItemParams] {
            sortItems(Runtime.shared.all(as: type).compactMap { (ref, entry) in
                ItemParams(ref: ref, name: entry.name, image: image)
            })
        }

        return .init(
            nesting: .recursive,
            sections: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    items: items(for: Sheet.self, image: "text.alignleft")
                ),
                .init(
                    id: "artifacts",
                    name: "Artifacts",
                    items: items(for: Artifact.self, image: "doc")
                ),
                .init(
                    id: "commands",
                    name: "Commands",
                    items: items(for: Command.self, image: "switch.2")
                ),
                .init(
                    id: "harnesses",
                    name: "Harnesses",
                    items: items(for: Harness.self, image: "arrow.2.squarepath")
                ),
            ],
        )
    }
}

struct NotificationsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        .init(
            nesting: .flat,
            sections: []
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
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
            sections: [
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
        return Controls(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        func sortWorkspaces(_ items: [ItemParams]) -> [ItemParams] {
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
                name: Space.with(ref, { $0.name }) ?? "Boundary",
                image: "app",
                items: sortWorkspaces(spaces)
            )
        }

        return .init(
            nesting: .recursive,
            sections: [
                .init(
                    id: "workspace",
                    name: "Workspace",
                    items: sortWorkspaces(Workspace.with(agency.session.workspace, { $0.spaces.map { space(for: $0, owner: agency.session.workspace, in: agency) } }) ?? [])
                )
            ]
        )
    }
}

struct ProjectMap: Mapper {
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        let spaces = SpacesMap.parameters(agency, panel).sections.flatMap { $0.items }
        let directories = DirectoryMap.parameters(agency, panel).sections.flatMap { $0.items }

        return .init(
            nesting: .recursive,
            sections: [
                .init(
                    id: "workspace",
                    name: "Workspace",
                    items: spaces
                ),
                .init(
                    id: "folders",
                    name: "Folders",
                    items: directories
                )
            ]
        )
    }
}
