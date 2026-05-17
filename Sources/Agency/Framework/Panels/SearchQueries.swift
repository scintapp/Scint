import SwiftUI
import AgencyRuntime


struct ActivityMapper: Mapper {
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
