import AgencyRuntime
import SwiftUI


struct BrowserMap: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focused == .structure(ref)
                || model.session.focused == .interface(ref)
                || model.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { model.select(ref) }
                else { model.open(ref) }
            },
            surfaceActions: {
                guard let owner = model.session.selected.space else { return [] }
                return Action.surfaceItems(for: owner)
            },
            surfaceDropTarget: {
                model.session.selected.space.map { .init(ref: $0, name: $0.descriptor.name) }
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let ref = model.session.selected.space else { return DashboardMap.parameters(model) }
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

struct CanvasMaps: Mapper {
    static func controls(_ model: any Model) -> Controls { BrowserMap.controls(model) }
    static func parameters(_ model: any Model) -> Params { BrowserMap.parameters(model) }
}

struct DashboardMap: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focused == .structure(ref)
                || model.session.focused == .interface(ref)
                || model.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { model.select(ref) }
                else { model.open(ref) }
            },
            surfaceActions: {
                Action.surfaceItems(for: model.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: model.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let spaces = Workspace.with(model.session.workspace, { $0.spaces }) ?? []
        let closure = Workspace.with(model.session.workspace, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.content }) } ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { space in
                return .init(
                    ref: space,
                    origin: model.session.workspace,
                    name: space.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
                .init(
                    ref: ref,
                    origin: model.session.workspace,
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

