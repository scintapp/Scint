import SwiftUI
import AgencyRuntime


struct OutlineMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        return .init(
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let origin = agency.session.space
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
                            guard case .task(let id, let title, let done) = entry else { return nil }

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

struct RootSpaceMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused(ref, entry: item.entryId, url: item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref, from: item.origin, entry: item.entryId, url: item.path)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin, entry: item.entryId, url: item.path)
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

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let spaces = Workspace.with(agency.session.workspace, { $0.spaces }) ?? []
        let closure = Workspace.with(agency.session.workspace, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.sheets }) }?.compactMap { Sheet.with($0, { $0 }) } ?? []
        let components = closure.flatMap { Closure.with($0, { $0.components }) } ?? []

        let spaceItems: [ItemParams] = spaces.compactMap { ref in
            guard let name = Space.with(ref, { $0.name }) else { return nil }
            return .init(ref: ref, origin: agency.session.workspace, name: name, image: Design.Component.icon(for: ref), tags: ["Space"])
        }

        let sheetItems: [ItemParams] = sheets.map { sheet in
            return .init(
                ref: sheet.ref,
                origin: agency.session.workspace,
                name: sheet.name,
                image: Design.Component.icon(for: sheet.ref),
                tags: ["Sheet"]
            )
        }

        let componentItems: [ItemParams] = components.map { ref in
            .init(
                ref: ref,
                origin: agency.session.workspace,
                name: Runtime.shared.get(ref).name,
                image: Design.Component.icon(for: ref),
                tags: [{
                    switch ref.type {
                    case is Artifact.Type: "Artifact"
                    case is Command.Type: "Control"
                    case is Harness.Type: "Harness"
                    case is Transcript.Type: "Transcript"
                    default: "Component"
                    }
                }()]
            )
        }

        return .init(
            sections: [
                .init(
                    id: "space",
                    showsHeader: false,
                    layout: .grid,
                    items: spaceItems + sheetItems + componentItems
                ),
            ],
            columns: [
                .init(title: "Name", width: 320, value: .primary),
                .init(title: "Kind", value: .tags)
            ]
        )
    }
}

struct SpaceMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused(ref, entry: item.entryId, url: item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref, from: item.origin, entry: item.entryId, url: item.path)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin, entry: item.entryId, url: item.path)
            },
            surfaceActions: {
                guard let owner = agency.session.space else { return [] }
                return Action.surfaceItems(for: owner)
            },
            surfaceDropTarget: {
                agency.session.space.map { .init(ref: $0, name: $0.name) }
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        guard let space = agency.session.space else { return RootSpaceMap.params(agency, panel) }
        let spaces = Space.with(space, { $0.spaces }) ?? []
        let routes = Space.with(space, { $0.routes }) ?? []
        let closure = Space.with(space, { $0.closure })
        let sheets = closure.flatMap { Closure.with($0, { $0.sheets }) }?.compactMap { Sheet.with($0, { $0 }) } ?? []
        let components = closure.flatMap { Closure.with($0, { $0.components }) } ?? []

        let spaceItems: [ItemParams] = spaces.compactMap { ref in
            guard let name = Space.with(ref, { $0.name }) else { return nil }
            return .init(ref: ref, origin: space, name: name, image: Design.Component.icon(for: ref), tags: ["Space"])
        }

        let sheetItems: [ItemParams] = sheets.map { sheet in
            return .init(
                ref: sheet.ref,
                origin: space,
                name: sheet.name,
                image: Design.Component.icon(for: sheet.ref),
                tags: ["Sheet"]
            )
        }

        let componentItems: [ItemParams] = components.map { ref in
            .init(
                ref: ref,
                origin: space,
                name: Runtime.shared.get(ref).name,
                image: Design.Component.icon(for: ref),
                tags: [{
                    switch ref.type {
                    case is Artifact.Type: "Artifact"
                    case is Command.Type: "Control"
                    case is Harness.Type: "Harness"
                    case is Transcript.Type: "Transcript"
                    default: "Component"
                    }
                }()]
            )
        }

        let routeItems: [ItemParams] = routes.compactMap { ref in
            guard let name = Route.with(ref, { $0.name }) else { return nil }
            return .init(ref: ref, origin: space, name: name, image: Design.Component.icon(for: ref), tags: ["Route"])
        }

        return .init(
            sections: [
                .init(
                    id: "space",
                    showsHeader: false,
                    layout: panel.layout,
                    items: spaceItems + sheetItems + componentItems + routeItems
                ),
            ],
            columns: [
                .init(title: "Name", width: 320, value: .primary),
                .init(title: "Kind", value: .tags)
            ]
        )
    }
}
