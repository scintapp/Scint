import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


struct ViewChrome<Content: View>: View {
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
        let content = ScrollView {
            VStack(alignment: .leading) {
                if params.header, params.layout == .group, let ref = params.ref {
                    GroupHeader(ref: ref)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, GroupMetrics.headerTop)
                        .padding(.bottom, 12)
                }

                ForEach(params.sections) { section in
                    let target = controls.sectionDropTarget?(section)
                    let types = target.map { controls.dropTypes?($0) ?? ReferenceTransfer.dropTypes(for: $0) } ?? []
                    let stack = VStack(spacing: 0) {
                        switch params.layout ?? .list {
                            case .group:
                                GroupFactory.build(surface, section, controls)

                            case .list:
                                ListFactory.build(surface, section, controls)

                            default:
                                EmptyView()
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
            content
                .contentShape(Rectangle())
        }
    }
}
