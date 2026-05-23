import SwiftUI
import AgencyRuntime



struct FoldersMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let expanded = agency.studio.content.expanded

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

struct LibraryMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        Closures(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
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
                    .init(name: "Skills", image: "sparkles", items: items(for: Service.self, image: "sparkles")),
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

struct NotificationsMapper: Mapper {
    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
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

struct WorkspaceMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let expanded = frame.expanded

        func sortBoundaryItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Space.Type
                let rhsBoundary = $1.ref?.type is Space.Type
                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

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

        func boundary(for ref: Reference, in agency: AgencyModel) -> ItemParams {
            let isExpanded = expanded.contains(AnyHashable(ref))
            let hasChildren = Space.with(ref, { b -> Bool in
                if !b.boundaries.isEmpty { return true }
                if Closure.with(b.closure, { !$0.sheets.isEmpty }) == true { return true }
                return false
            }) ?? false

            let children: [ItemParams]

            if isExpanded {
                let sheets = Space.with(ref, { $0.closure })
                    .flatMap { Closure.with($0, { $0.sheets }) }?
                    .compactMap { Sheet.with($0, { $0 }) }
                    .map { sheet in ItemParams(ref: sheet.ref,origin: ref,name: sheet.name,image: "text.alignleft") } ?? []

                let boundaries = Space.with(ref, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? []
                children = sortBoundaryItems(boundaries + sheets) } else { children = [] }

            return .init(
                ref: ref,
                name: Space.with(ref, { $0.name }) ?? "Boundary",
                image: "app",
                items: children,
                isParent: hasChildren
            )
        }

        return .init(
            nesting: .recursive,
            sections: [
                .init(
                    id: "filters",
                    showsHeader: false,
                    items: [
                        .init(name: "Drafts", image: "tray"),
                        .init(name: "Automations", image: "timer")
                    ]
                ),
                .init(
                    id: "space",
                    name: "Space",
                    items: sortBoundaryItems(Workspace.with(agency.session.space, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? [])
                ),
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFileItems(agency.artifacts.roots.compactMap { folder(for: $0, in: agency) })
                )
            ]
        )
    }
}

//struct WorkspaceMapper: Mapper {
//    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
//        return Closures(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                return agency.session.selected(ref, item.path)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, url: item.path)
//            }
//        )
//    }
//
//    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
//        func sortBoundaries(_ items: [ItemParams]) -> [ItemParams] {
//            items.sorted {
//                let lhsBoundary = $0.ref?.type is Space.Type
//                let rhsBoundary = $1.ref?.type is Space.Type
//                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
//                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
//            }
//        }
//
//        func sortFiles(_ items: [ItemParams]) -> [ItemParams] {
//            items.sorted {
//                let lhsDirectory = $0.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
//                let rhsDirectory = $1.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
//                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
//                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
//            }
//        }
//
//        func file(for entry: Artifact.Entry, root: Reference, in agency: AgencyModel) -> ItemParams? {
//            guard let url = entry.url else { return nil }
//            let isDirectory = agency.artifacts.isDirectory(at: url)
//            return .init(
//                ref: root,
//                path: url,
//                name: entry.name,
//                image: isDirectory ? "folder" : "doc",
//                items: isDirectory ? sortFiles(agency.artifacts.children(of: entry).compactMap {
//                    file(for: .file($0), root: root, in: agency)
//                }) : []
//            )
//        }
//
//        func folder(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
//            guard let entry = Artifact.with(ref, { $0.entry }), let url = entry.url else { return nil }
//            let isDirectory = agency.artifacts.isDirectory(at: url)
//            return .init(
//                ref: ref,
//                path: url,
//                name: Runtime.shared.get(ref).name,
//                image: isDirectory ? "folder" : "doc",
//                items: isDirectory ? sortFiles(agency.artifacts.children(of: entry).compactMap {
//                    file(for: .file($0), root: ref, in: agency)
//                }) : []
//            )
//        }
//
//        func boundary(for ref: Reference, in agency: AgencyModel) -> ItemParams {
//            let sheets: [ItemParams] = []
//
//            let boundaries = Space.with(ref, {
//                $0.boundaries.map { boundary(for: $0, in: agency) }
//            }) ?? []
//
//            return .init(
//                ref: ref,
//                name: Space.with(ref, { $0.name }) ?? "Boundary",
//                image: "app",
//                items: sortBoundaries(boundaries + sheets)
//            )
//        }
//
//        return .init(
//            nesting: .recursive,
//            sections: [
//                .init(
//                    id: "filters",
//                    showsHeader: false,
//                    items: [
//                        .init(name: "Drafts", image: "tray"),
//                        .init(name: "Automations", image: "timer")
//                    ]
//                ),
//                .init(
//                    id: "space",
//                    name: "Space",
//                    items: sortBoundaries(Workspace.with(agency.session.space, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? [])
//                ),
//                .init(
//                    id: "folders",
//                    name: "Folders",
//                    items: sortFiles(agency.artifacts.roots.compactMap { folder(for: $0, in: agency) }),
//                )
//            ]
//        )
//    }
//}
