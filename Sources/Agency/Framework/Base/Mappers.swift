import SwiftUI
import AgencyRuntime


struct ArtifactsMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
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

    static func params(_ agency: AgencyModel) -> Params {
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

struct BoundaryMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
        let expanded = frame.expanded

        func sortBoundaryItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Boundary.Type
                let rhsBoundary = $1.ref?.type is Boundary.Type
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
            let hasChildren = Boundary.with(ref, { b -> Bool in
                if !b.boundaries.isEmpty { return true }
                if Closure.with(b.closure, { !$0.sheets.isEmpty }) == true { return true }
                return false
            }) ?? false

            let children: [ItemParams]

            if isExpanded {
                let sheets = Boundary.with(ref, { $0.closure })
                    .flatMap { Closure.with($0, { $0.sheets }) }?
                    .compactMap { Sheet.with($0, { $0 }) }
                    .map { sheet in ItemParams(ref: sheet.ref,origin: ref,name: sheet.name,image: "text.alignleft") } ?? []

                let boundaries = Boundary.with(ref, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? []
                children = sortBoundaryItems(boundaries + sheets) } else { children = [] }

            return .init(
                ref: ref,
                name: Boundary.with(ref, { $0.name }) ?? "Boundary",
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
                    items: sortBoundaryItems(Space.with(agency.session.space, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? [])
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

struct BrowserMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        return Closures()
    }

    static func params(_ agency: AgencyModel) -> Params {
        func space(for ref: Reference) -> ItemParams {
            .init(
                ref: ref,
                name: Space.with(ref, { $0.name }) ?? "Space",
                image: "cube.transparent"
            )
        }

        return .init(
            nesting: .flat,
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
                    id: "spaces",
                    name: "Spaces",
                    items: Runtime.shared.spaces.map { space(for: $0) }
                )
            ]
        )
    }
}

struct CompositionMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
        .init(
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
        let origin = agency.session.boundary ?? agency.session.space

        guard let components = Boundary.with(origin, { Closure.with($0.closure, { $0.components }) }) ?? [] else {
            return Params()
        }

        let closures: [ItemParams] = components
            .filter { $0.type is Control.Type }
            .compactMap { control in
                guard let name = Control.with(control, { $0.name }) else { return nil }
                return .init(
                    ref: control,
                    origin: origin,
                    name: name,
                    image: "switch.2",
                    tint: Design.Tint.control
                )
            }

        let serviceItems: [ItemParams] = components
            .filter { $0.type is Service.Type }
            .compactMap { r in
                guard let name = Service.with(r, { $0.name }) else { return nil }
                return .init(
                    ref: r,
                    origin: origin,
                    name: name,
                    image: "arrow.2.squarepath",
                    tint: Design.Tint.service
                )
            }

        return Params(
            sections: [
                .init(
                    id: "automation",
                    name: "Automation",
                    layout: .group,
                    footnote: "Automate when and how often this boundary runs.",
                    items: [
                        ItemParams(name: "Date",   image: "calendar", trailingKind: .toggle),
                        ItemParams(name: "Time",   image: "clock",    trailingKind: .toggle),
                        ItemParams(name: "Repeat", image: "repeat",   trailingKind: .toggle),
                    ]
                ),
                .init(
                    id: "settings",
                    name: "Settings",
                    layout: .group,
                    footnote: "Load closures and services from the library into this boundary.",
                    items: [
                        .init(
                            name: "Controls",
                            image: "switch.2",
                            trailingKind: .load,
                            count: closures.count,
                            items: closures
                        ),
                        .init(
                            name: "Services",
                            image: "arrow.2.squarepath",
                            trailingKind: .load,
                            count: serviceItems.count,
                            items: serviceItems
                        ),
                    ]
                ),
            ]
        )
    }
}

struct DetailMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return agency.session.selected(ref, entry) }
                return agency.session.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin, entry: item.entryId)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
        let origin = agency.session.boundary
        let sheets = origin
            .flatMap { Boundary.with($0, { $0.closure }) }
            .flatMap { Closure.with($0, { $0.sheets }) }?
            .compactMap { Sheet.with($0, { $0 }) } ?? []

        return .init(
            sections: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    layout: .list,
                    items: sheets.map { sheet in
                            .init(
                                ref: sheet.ref,
                                origin: origin,
                                name: sheet.name,
                                image: "text.alignleft"
                            )
                    }
                ),
                .init(
                    id: "tasks",
                    name: "Tasks",
                    layout: .list,
                    items: sheets.flatMap { sheet in
                        sheet.entries.compactMap { entry -> ItemParams? in
                            guard case .todo(let id, let title, let done) = entry else { return nil }

                            return .init(
                                ref: sheet.ref,
                                origin: origin,
                                entryId: id,
                                name: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                image: done ? "checkmark.app.fill" : "checkmark.app",
                                description: sheet.name,
                                active: done
                            )
                        }
                    }
                )
            ]
        )
    }
}

struct LibraryMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
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
    static func closures(_ agency: AgencyModel) -> Closures { .init() }

    static func params(_ model: AgencyModel) -> Params {
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

struct PreviewMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
        .init()
    }

    static func params(_ studio: AgencyModel, _ frame: any Frame) -> Params {
        .init(
            sections: [
                .init(
                    id: "context",
                    name: "Context",
                    layout: .block,
                    footnote: "The context that will be sent on the next turn.",
                    body: ""
                ),
                .init(
                    id: "output",
                    name: "Last Output",
                    layout: .block,
                    footnote: "The most recent output produced by this boundary.",
                    body: ""
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    layout: .block,
                    footnote: "Token usage from the last turn.",
                    items: [
                        ItemParams(name: "Input Tokens",  trailingKind: .value, description: "0"),
                        ItemParams(name: "Cached Tokens", trailingKind: .value, description: "0"),
                        ItemParams(name: "Output Tokens", trailingKind: .value, description: "0"),
                    ]
                ),
            ]
        )
    }
}
