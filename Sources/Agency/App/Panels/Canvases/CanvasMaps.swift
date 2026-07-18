import AgencyRuntime
import SwiftUI


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
        let state = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

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
                    items: spaceItems + stateItems.filter { $0.ref?.type == Sheet.self && $0.name != "Input" }
                )
            ]
        )
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
        guard let ref = agency.session.selected.space else { return DashboardMap.parameters(agency) }
        let closure = Space.with(ref, { $0.closure })
        let content = closure.flatMap { Closure.with($0, { $0.content }) } ?? []
        let spaces = Space.with(ref, { $0.spaces }) ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { child in
                return .init(
                    ref: child,
                    origin: ref,
                    name: child.descriptor.name
                )
            }

        let contentItems: [ItemParams] = content.map { ref in
                .init(
                    ref: ref,
                    origin: ref,
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
                    items: spaceItems + contentItems.filter { $0.ref?.type == Sheet.self && $0.name != "Input" }
                ),
            ]
        )
    }
}

