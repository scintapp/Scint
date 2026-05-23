import SwiftUI
import AgencyRuntime


struct OutlineMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let origin = agency.session.boundary
        let sheets = origin
            .flatMap { Space.with($0, { $0.closure }) }
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

struct SpaceMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
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

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let origin = agency.session.boundary
        let sheets = origin
            .flatMap { Space.with($0, { $0.closure }) }
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
