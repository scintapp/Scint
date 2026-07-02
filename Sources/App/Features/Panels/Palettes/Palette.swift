import AgencyRuntime
import SwiftUI


struct PaletteRow: View {
    let item: ItemParams
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                if let ref = item.ref {
                    Iconography.icon(for: ref, size: 13)
                } else {
                    Image(systemName: item.image.isEmpty ? "square.stack.3d.up" : item.image)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16.5))
                    .foregroundStyle(isSelected ? Color.primary.opacity(1) : .primary.opacity(0.85))
                    .lineLimit(1)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

struct PaletteInput: View {
    @Binding var query: String
    let image: String
    let placeholder: String
    let focused: FocusState<Bool>.Binding
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: image)
                .foregroundStyle(.secondary.opacity(0.8))
                .font(.system(size: 24))

            TextField(placeholder, text: $query)
                .foregroundStyle(.primary)
                .font(.system(size: 26))
                .textFieldStyle(.plain)
                .focused(focused)
                .onKeyPress(.upArrow) { onUpArrow() }
                .onKeyPress(.downArrow) { onDownArrow() }
                .onKeyPress(.return) { onReturn() }
                .onKeyPress(.tab) { onTab() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

@Observable final class Palette: Panel {
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []
    var index: Int = 0
    var query: String = ""

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { "\(label)" }

        var label: String {
            switch self {
                case .commands: "Commands"
                case .interfaces: "Interfaces"
                case .library: "Library"
                case .workspace: "Workspace"
            }
        }

        var image: String {
            switch self {
                case .commands: "command"
                case .interfaces: "switch.2"
                case .library: "building.columns"
                case .workspace: "cube.transparent"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        SearchMap.parameters(agency, self)
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var search = agency.studio.palette
        @FocusState var focused: Bool
        var params: PanelParams { agency.studio.palette.parameters(agency) }
        var flatItems: [ItemParams] { params.components.flatMap { $0.items } }

        func reset() {
            query = ""
            index = 0
        }

        func move(_ delta: Int) {
            let count = flatItems.count
            guard count > 0 else { return }
            agency.studio.palette.index = (agency.studio.palette.index + delta + count) % count
        }

        func action() {
            guard flatItems.indices.contains(agency.studio.palette.index) else { return }
            let item = flatItems[agency.studio.palette.index]

            agency.studio.palette.controls(agency).onSelect?(item)
            dismiss()
        }

        func content() {
            let modes = Model.allCases
            guard let current = modes.firstIndex(of: agency.studio.palette.model) else { return }
            agency.studio.palette.model = modes[(current + 1) % modes.count]
        }

        func dismiss() {
            focused = true
            reset()
            agency.panels.panels["search"]?.hide()
        }

        return VStack(alignment: .leading, spacing: 0) {
            PaletteInput(
                query: $search.query,
                image: agency.studio.palette.model.image,
                placeholder: agency.studio.palette.model.placeholder,
                focused: $focused,
                onUpArrow: { move(-1); return .handled },
                onDownArrow: { move(+1); return .handled },
                onReturn: { action(); return .handled },
                onTab: { content(); return .handled }
            )
            PaletteContent()
                .view(agency)
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .onChange(of: agency.studio.palette.query) { _, _ in agency.studio.palette.index = 0 }
        .onChange(of: agency.studio.palette.model) { _, _ in reset(); focused = true }
        .background {
            ZStack {
                Button { agency.studio.palette.model = .commands } label: { EmptyView() }
                    .keyboardShortcut("1", modifiers: .command)
                Button { agency.studio.palette.model = .interfaces } label: { EmptyView() }
                    .keyboardShortcut("2", modifiers: .command)
                Button { agency.studio.palette.model = .library } label: { EmptyView() }
                    .keyboardShortcut("3", modifiers: .command)
                Button { agency.studio.palette.model = .workspace } label: { EmptyView() }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }
}
