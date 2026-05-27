import SwiftUI
import AgencyRuntime


struct DirectoryMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        return Closures(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin, url: item.path)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let expanded = agency.studio.navigator.expanded

        func sortFileItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
                let rhsDirectory = $1.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Entry, root: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let isDirectory = entry.isDirectory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = (isDirectory && isExpanded)
            ? sortFileItems(agency.artifacts.children(of: entry).compactMap { file(for: .file($0), root: root, in: agency) })
            : []

            return .init(
                ref: root,
                path: url,
                name: entry.name,
                image: isDirectory ? "folder" : "doc",
                items: children,
                isParent: isDirectory
            )
        }

        func folder(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.entry }), let url = entry.url else { return nil }
            let isDirectory = entry.isDirectory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = (isDirectory && isExpanded)
            ? sortFileItems(agency.artifacts.children(of: entry).compactMap { file(for: .file($0), root: ref, in: agency) })
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
                    items: sortFileItems(agency.artifacts.roots.compactMap { folder(for: $0, in: agency) })
                )
            ]
        )
    }
}

struct LibraryMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
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
                .init(name: "Artifacts", items: [
                    .init(name: "Links", image: "link", items: items(for: Artifact.self, image: "link")),
//                    .init(name: "Skills", image: "sparkles", items: items(for: Service.self, image: "sparkles")),
                    .init(name: "Templates", image: "list.bullet.rectangle", items: items(for: Sheet.self, image: "list.bullet.rectangle")),
                ]),
                .init(name: "Interfaces", items: [
                    .init(name: "Controls", image: "switch.2", items: items(for: Control.self, image: "switch.2")),
                    .init(name: "Services", image: "arrow.2.squarepath", items: items(for: Service.self, image: "arrow.2.squarepath")),

                ])
            ],
        )
    }
}

struct NotificationsMap: Mapper {
    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        .init(
            nesting: .flat,
            sections: [
                .init(
                    name: "Notifications",
                    showsHeader: false,
                    items: []
                )
            ]
        )
    }
}

struct WorkspacesMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        return Closures(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
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

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
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
            let sheets: [ItemParams] = []

            return .init(
                ref: ref,
                origin: owner,
                name: Space.with(ref, { $0.name }) ?? "Boundary",
                image: "app",
                items: sortWorkspaces(spaces + sheets)
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

struct WorkspaceMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        return Closures(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin, url: item.path)
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

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let spaces = WorkspacesMap.params(agency, panel).sections.flatMap { $0.items }
        let directories = DirectoryMap.params(agency, panel).sections.flatMap { $0.items }

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
