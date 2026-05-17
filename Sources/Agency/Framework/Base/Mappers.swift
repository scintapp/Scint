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

    static func params(_ agency: AgencyModel) -> Params { .init() }

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

struct CatalogMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
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

    static func params(_ agency: AgencyModel) -> Params {
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

struct ContentMapper: Mapper {
    static func params(_ agency: AgencyModel) -> Params {
        let query = agency.search.query
        let results = Runtime.shared
            .search(query, limit: 50)
            .all
            .filter { $0.ref.type is Sheet.Type || $0.ref.type is Journal.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "content",
                    name: "Content",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }

    static func closures(_ agency: AgencyModel) -> Closures {
        Closures(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.open(ref)
            }
        )
    }
}

struct DetailMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
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

    static func params(_ agency: AgencyModel) -> Params {
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

struct InterfacesMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        Closures(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel) -> Params {
        let services = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Service.Type }
        let closures = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Control.Type }
        let artifacts = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Artifact.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "services", name: "Services", items: services.map(item(from:))),
                .init(id: "closures", name: "Controls", items: closures.map(item(from:))),
                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct LibraryMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
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

    static func params(_ agency: AgencyModel) -> Params {
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
    static func closures(_ agency: AgencyModel) -> Closures {
        Closures()
    }

    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
        Closures()
    }

    static func params(_ studio: AgencyModel) -> Params { .init() }

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

struct ProcessMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        return .init()
    }

    static func params(_ agency: AgencyModel) -> Params {
        let query = "\(agency.search.query) !service"
        let results = Runtime.shared.search(query, limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "processes",
                    name: "Processes",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct SpacesMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel) -> Params {
        let results = Runtime.shared
            .search(agency.search.query, limit: 50)
            .all
            .filter { $0.ref.type is Boundary.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "space",
                    name: "Space",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct SpaceMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        return Closures(
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

    static func params(_ agency: AgencyModel) -> Params {
        func sortBoundaries(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Boundary.Type
                let rhsBoundary = $1.ref?.type is Boundary.Type
                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func sortFiles(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
                let rhsDirectory = $1.path.map { agency.artifacts.isDirectory(at: $0) } ?? false
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Entry, root: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let isDirectory = agency.artifacts.isDirectory(at: url)
            return .init(
                ref: root,
                path: url,
                name: entry.name,
                image: isDirectory ? "folder" : "doc",
                items: isDirectory ? sortFiles(agency.artifacts.children(of: entry).compactMap {
                    file(for: .file($0), root: root, in: agency)
                }) : []
            )
        }

        func folder(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.entry }), let url = entry.url else { return nil }
            let isDirectory = agency.artifacts.isDirectory(at: url)
            return .init(
                ref: ref,
                path: url,
                name: Runtime.shared.get(ref).name,
                image: isDirectory ? "folder" : "doc",
                items: isDirectory ? sortFiles(agency.artifacts.children(of: entry).compactMap {
                    file(for: .file($0), root: ref, in: agency)
                }) : []
            )
        }

        func boundary(for ref: Reference, in agency: AgencyModel) -> ItemParams {
            let sheets: [ItemParams] = []

            let boundaries = Boundary.with(ref, {
                $0.boundaries.map { boundary(for: $0, in: agency) }
            }) ?? []

            return .init(
                ref: ref,
                name: Boundary.with(ref, { $0.name }) ?? "Boundary",
                image: "app",
                items: sortBoundaries(boundaries + sheets)
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
                    items: sortBoundaries(Space.with(agency.session.space, { $0.boundaries.map { boundary(for: $0, in: agency) } }) ?? [])
                ),
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFiles(agency.artifacts.roots.compactMap { folder(for: $0, in: agency) }),
                )
            ]
        )
    }
}

struct SheetsMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin)
            }
        )
    }

    static func params(_ agency: AgencyModel) -> Params {
        let origin = agency.session.boundary
        let sheets = origin
            .flatMap { Boundary.with($0, { $0.closure }) }
            .flatMap { Closure.with($0, { $0.sheets }) }?
            .compactMap { Sheet.with($0, { $0 }) } ?? []

        return .init(
            sections: [
                .init(
                    id: "sheets",
                    showsHeader: false,
                    layout: .grid,
                    items: sheets.map { sheet in
                        let closures = sheet.entries.reduce(into: 0) { total, entry in if case .control = entry { total += 1 } }
                        let artifacts = sheet.entries.reduce(into: 0) { total, entry in if case .artifact = entry { total += 1 } }
                        let tasks = sheet.entries.reduce(into: 0) { total, entry in if case .todo = entry { total += 1 } }

                        return .init(
                            ref: sheet.ref,
                            origin: origin,
                            name: sheet.name,
                            image: "text.alignleft",
                            description: sheet.content,
                            badges: [
                                .init(icon: "switch.2", label: "", count: closures, tint: Design.Tint.control),
                                .init(icon: "archivebox", label: "", count: artifacts, tint: Design.Tint.artifact),
                                .init(icon: "checkmark.app", label: "", count: tasks, tint: Design.Tint.task),
                            ]
                        )
                    }
                )
            ]
        )
    }
}

struct SheetMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures { return .init() }

    static func params(_ agency: AgencyModel) -> Params {
        let query = "\(agency.search.query) !sheet"
        let results = Runtime.shared.search(query, limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    showsHeader: false,
                    items: results.map(item(from:))
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

    static func params(_ agency: AgencyModel) -> Params {
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

struct SearchMapper: Mapper {
    static func closures(_ agency: AgencyModel) -> Closures { .init() }

    static func params(_ agency: AgencyModel) -> Params {
        let query = agency.search.query
        let space = Runtime.shared.search("\(query) !structural",  limit: 50).all
        let sheets = Runtime.shared.search("\(query) !sheet", limit: 50).all
        let interfaces = Runtime.shared.search("\(query) !interfacing", limit: 50).all
        let processes = Runtime.shared.search("\(query) !service", limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "space", name: "Space", image: "cube.transparent", items: space.map(item(from:))),
                .init(id: "sheets", name: "Sheets", image: "text.alignleft", items: sheets.map(item(from:))),
                .init(id: "interfaces", name: "Interfaces", image: "switch.2", items: interfaces.map(item(from:))),
                .init(id: "processes", name: "Processes", image: "arrow.2.squarepath", items: processes.map(item(from:))),
            ]
        )
    }
}
