import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct PanelFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        let state = surface.host.state
        let compact = if case .anchored? = params.panel?.placement { true } else { false }
        let shown = sections(params, controls, state)
        let fields = shown.flatMap(\.items).filter { $0.trailingKind == .field }
        let rows = choices(shown)
        let cursor = rows.isEmpty ? nil : rows[min(state.index, rows.count - 1)]
        let onKey = { (press: KeyPress) in handle(press.key, surface) }

        PanelLayout(size: params.panel?.size ?? CGSize(width: Metrics.menuWidth, height: Metrics.menuListHeight), compact: compact, focusable: fields.isEmpty, current: cursor?.id, onKey: onKey
        ) {
            if params.header, let ref = params.ref { PanelReference(ref) }

            ForEach(fields) { field in
                PanelField(text: surface.host.bindable.query, field: field, compact: compact, onKey: onKey)
            }

            if params.tabbed {
                PanelModes(tabs: params.sections, active: shown.first?.id) { select($0, state) }
                    .background { PanelShortcuts(count: params.sections.count) { select(params.sections[$0], state) } }
            }

        } content: {
            if rows.isEmpty, !shown.contains(where: { $0.layout == .group }) { NoReference(title: params.description) }

            ForEach(Array(shown.enumerated()), id: \.element.id) { index, section in
                if section.layout == .group { GroupFactory.build(surface, section, controls) }
                else { build(section, first: index == 0, cursor, compact, controls) }
            }
        }
        .onChange(of: state.query) { _, _ in state.index = 0 }
    }

    @ViewBuilder static func build(_ section: SectionParams, first: Bool, _ current: ItemParams?, _ compact: Bool, _ controls: Controls) -> some View {
        let items = section.items.filter { $0.trailingKind != .field }

        if section.header, !section.name.isEmpty { PanelHeader(name: section.name) }

        ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
            if item.isParent {
                if !item.name.isEmpty { PanelHeader(name: item.name) }
                else if offset > 0 || !first { Divider().opacity(Style.Opacity.inactive).padding(.horizontal, 6) }
                ForEach(item.items) { build($0, current, compact, controls) }
            } else {
                build(item, current, compact, controls)
            }
        }
    }

    @ViewBuilder static func build(_ item: ItemParams, _ current: ItemParams?, _ compact: Bool, _ controls: Controls) -> some View {
        PanelRow(item: item, active: item == current, selected: controls.selected?(item) ?? false, compact: compact) { controls.onSelect?(item) }
            .id(item.id)
    }

    static func sections(_ params: Params, _ controls: Controls, _ state: StateContainer) -> [SectionParams] {
        let tab = params.sections.first { $0.id == AnyHashable(state.surface) } ?? params.sections.first
        return (params.tabbed ? [tab].compactMap { $0 } : params.sections).map { section in
            var section = section
            section.items += controls.results?(section, state.query) ?? []
            return section
        }
    }

    static func choices(_ sections: [SectionParams]) -> [ItemParams] {
        sections
            .filter { $0.layout != .group }
            .flatMap(\.items)
            .flatMap { $0.isParent ? $0.items : [$0] }
            .filter { $0.trailingKind != .field }
    }

    static func current(_ surface: some Surface) -> ItemParams? {
        let rows = choices(sections(surface.host.parameters(surface.model), surface.host.controls(surface.model), surface.host.state))
        return rows.isEmpty ? nil : rows[min(surface.host.state.index, rows.count - 1)]
    }

    static func move(_ surface: some Surface, by delta: Int) {
        let state = surface.host.state
        let count = choices(sections(surface.host.parameters(surface.model), surface.host.controls(surface.model), state)).count
        guard count > 0 else { return }
        state.index = (min(state.index, count - 1) + delta + count) % count
    }

    static func choose(_ surface: some Surface) {
        guard let item = current(surface) else { return }
        surface.host.controls(surface.model).onSelect?(item)
    }

    static func select(_ tab: SectionParams, _ state: StateContainer) {
        state.surface = tab.id.base as? String ?? ""
        state.query = ""
        state.index = 0
    }

    static func handle(_ key: KeyEquivalent, _ surface: some Surface) -> KeyPress.Result {
        let state = surface.host.state

        switch key {
            case .upArrow: move(surface, by: -1)
            case .downArrow: move(surface, by: 1)
            case .return: choose(surface)
            case .tab:
                guard let onAction = surface.host.controls(surface.model).onAction, let item = current(surface)
                else { move(surface, by: 1); return .handled }
                onAction(item)
                state.detail = true
                state.index = 0
            case .escape:
                guard state.detail else { return .ignored }
                state.detail = false
                state.index = 0
            default:
                return .ignored
        }
        return .handled
    }
}
