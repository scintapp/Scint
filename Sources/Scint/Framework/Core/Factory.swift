import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


struct ViewContainer<Content: View>: View {
    var item: ItemParams
    var controls: Controls
    var model: any Model
    @ViewBuilder var content: Content

    var types: [UTType] { controls.dropTypes?(item) ?? ReferenceTransfer.dropTypes(for: item) }

    @ViewBuilder var dropped: some View {
        if types.isEmpty { content.contentShape(Rectangle()) }
        else {
            content
                .contentShape(Rectangle())
                .onDrop(of: types, isTargeted: nil) { controls.onDrop?($0, item) ?? ReferenceTransfer.handle($0, target: item) }
        }
    }

    @ViewBuilder var dragged: some View {
        if ReferenceTransfer.canDrag(item) { dropped.onDrag { ReferenceTransfer.provider(for: item) ?? NSItemProvider() } }
        else { dropped }
    }

    var body: some View {
        if let palette = controls.itemPalette?(item) { dragged.contextMenu { ActionMenu(model: model, items: palette) } }
        else { dragged }
    }
}


@MainActor struct Factory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        let state = surface.host.state
        let tab = params.tab(state.surface)
        let shown = params.shown(state.surface)

        if let panel = params.panel {
            let compact = if case .anchored = panel.placement { true } else { false }
            let scoped = { var scoped = controls; scoped.focused = { $0.id == params.cursor }; return scoped }()

            PanelLayout(size: panel.size, focusable: params.input == nil, current: params.cursor, onInput: controls.onInput) {
                if params.header, let ref = params.ref { PanelReference(ref) }

                if let input = params.input {
                    PanelField(text: .init(get: { input.value ?? "" }, set: { controls.onValueChange?(input, $0) }), field: input, onInput: controls.onInput)
                }

                if params.tabbed {
                    let select = controls.onTabSelect ?? { state.surface = $0.id.base as? String ?? "" }
                    PanelModes(tabs: params.sections, active: tab?.id, onSelect: select)
                        .background { PanelShortcuts(count: params.sections.count) { select(params.sections[$0]) } }
                }
            } content: {
                if shown.allSatisfy(\.items.isEmpty) { NoReference(title: params.description) }

                ForEach(Array(shown.enumerated()), id: \.element.id) { index, section in
                    if index > 0, section.name.isEmpty { Divider().opacity(Style.Opacity.inactive).padding(.horizontal, 6) }

                    if section.layout == .group { GroupFactory.build(surface, section, controls) }
                    else { PanelFactory.build(surface, section, scoped) }
                }
            }
            .controlSize(compact ? .small : .regular)
        } else {
            let content = ScrollView {
                VStack(alignment: .leading) {
                    if params.header, params.layout == .group, let ref = params.ref {
                        GroupHeader(
                            ref: ref,
                            subtitle: params.name,
                            described: params.described,
                            tabs: params.tabbed ? params.sections.filter(\.header) : [],
                            active: tab?.id,
                            onSelect: { state.surface = $0.id == tab?.id ? "" : $0.id.base as? String ?? "" }
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, GroupMetrics.headerTop)
                        .padding(.bottom, 12)
                    }

                    ForEach(shown) { section in
                        let target = controls.sectionDropTarget?(section)
                        let types = target.map { controls.dropTypes?($0) ?? ReferenceTransfer.dropTypes(for: $0) } ?? []
                        let stack = VStack(spacing: 0) {
                            switch params.layout ?? .list {
                                case .group: GroupFactory.build(surface, section, controls)
                                case .list: ListFactory.build(surface, section, controls)
                                default: EmptyView()
                            }
                        }

                        Group {
                            if let target, !types.isEmpty { stack.onDrop(of: types, isTargeted: nil) { controls.onDrop?($0, target) ?? ReferenceTransfer.handle($0, target: target) } }
                            else { stack }
                        }
                        .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            }

            if let target = controls.surfaceDropTarget?() {
                content
                    .contentShape(Rectangle())
                    .onDrop(of: controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target), isTargeted: nil) {
                        controls.onDrop?($0, target) ?? ReferenceTransfer.handle($0, target: target)
                    }
            } else {
                content.contentShape(Rectangle())
            }
        }
    }
}
