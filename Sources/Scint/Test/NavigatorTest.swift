import SwiftUI
import UniformTypeIdentifiers
import ScintComponents
import ScintRuntime


struct NavigatorRow: View {
    @State private var anchor = PanelAnchor.Box()
    var ref: Reference
    var model: any Model

    var root: Bool { Space.with(model.session.spaces, { $0.spaces.contains(ref) }) ?? false }

    var working: Int {
        Runtime.shared.all(as: Space.self).count { space, _ in
            switch (space.context?.state, Navigation().spaces(to: space).dropFirst().contains(ref)) {
                case (.active, true), (.working, true): true
                default: false
            }
        }
    }

    var body: some View {
        Label {
            Text(ref.descriptor.name)
        } icon: {
            if root {
                Iconography.icon(for: ref, size: 14)
                    .foregroundStyle(Style.Foreground.secondary)
            }
            else {
                Iconography.Dot(ref: ref, tint: Iconography.dot(for: ref).tint, sizing: 15 * Iconography.dotScale)
            }
        }
        .badge(working)
        .itemProvider { ReferenceTransfer.provider(for: ref) }
        .onDrop(of: UTType.scint, isTargeted: nil) { ReferenceTransfer.handle($0, target: ref, sharing: true) }
        .background(PanelAnchor(box: anchor))
        .contextMenu { ContextMenu(ref: ref, model: model, anchor: anchor) }
    }
}

struct NavigatorTree<Row: View>: View {
    var ref: Reference
    @ViewBuilder var row: (Reference) -> Row

    var spaces: [Reference] {
        Space.with(ref) { $0.spaces.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending } } ?? []
    }

    var body: some View {
        ForEach(spaces) { space in
            if Space.with(space, { $0.spaces.isEmpty }) ?? true { row(space).tag(space) }
            else {
                DisclosureGroup {
                    NavigatorTree(ref: space, row: row)
                } label: {
                    row(space).tag(space)
                }
            }
        }
    }
}

struct ShortcutsSection: View {
    var model: any Model

    var body: some View {
        Section {
            Label("Agenda", systemImage: "calendar")
                .contextMenu { ContextMenu(ref: model.session.agenda, model: model) }
                .tag(model.session.agenda)
            Label("Documents", systemImage: "document.on.document")
                .contextMenu { ContextMenu(ref: model.session.library, model: model) }
                .tag(model.session.library)
            Label("Spaces", systemImage: "cube.transparent")
                .contextMenu { ContextMenu(ref: model.session.spaces, model: model) }
                .tag(model.session.spaces)
        }
    }
}

struct SpacesSection: View {
    @State private var expanded = true
    var model: any Model

    var body: some View {
        Section(isExpanded: $expanded) {
            NavigatorTree(ref: model.session.spaces) { NavigatorRow(ref: $0, model: model) }
        } header: {
            Text(model.session.spaces.descriptor.name)
                .contextMenu { ContextMenu(ref: model.session.spaces, model: model) }
        }
    }
}

struct LibrarySection: View {
    @State private var expanded = true
    var model: any Model

    var body: some View {
        Section(isExpanded: $expanded) {
            NavigatorTree(ref: model.session.library) { ref in
                Label(ref.descriptor.name, systemImage: "folder")
                    .listItemTint(Style.Foreground.secondary)
                    .itemProvider { ReferenceTransfer.provider(for: ref) }
                    .onDrop(of: UTType.scint, isTargeted: nil) { ReferenceTransfer.handle($0, target: ref) }
                    .contextMenu { ContextMenu(ref: ref, model: model) }
            }
        } header: {
            Text(model.session.library.descriptor.name)
                .contextMenu { ContextMenu(ref: model.session.library, model: model) }
        }
    }
}

struct NavigatorContent: Surface {
    var host: any Host
    var model: any Model

    var body: some View {
        VStack(alignment: .leading) {
            Color.clear.frame(height: 8)

            List(selection: .init(get: { model.session.selection.structure }, set: { if let ref = $0 { model.select(ref) } })) {
                ShortcutsSection(model: model)
                SpacesSection(model: model)
                LibrarySection(model: model)
            }
            .listStyle(.sidebar)
        }
    }
}

@Observable final class Navigator: Frame {
    var state: StateContainer = .init(presented: true)
    var surface: HostSurface = .navigator

    enum HostSurface: String, CaseIterable, Identifiable {
        case navigator
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var image: String { "sidebar.squares.left" }
    }

    func surface(_ model: AppModel) -> some View {
        ZStack(alignment: .trailing) {
            NavigatorContent(host: self, model: model)
                .toolbar(removing: .sidebarToggle)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .toolbar {
                    ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                    ToolbarSpacer(.flexible, placement: .automatic)
                    ToolbarItem(placement: .automatic) { }
                }
            Rectangle()
                .fill(Style.Border.base)
                .ignoresSafeArea()
                .frame(width: 1, alignment: .trailing)
                .frame(maxHeight: .infinity)
            Rectangle()
                .fill(.black)
                .ignoresSafeArea()
                .frame(width: 0.5, alignment: .trailing)
                .frame(maxHeight: .infinity)
        }
    }
}
