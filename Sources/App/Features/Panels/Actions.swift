import AgencyRuntime
import SwiftUI
import Foundation


struct ControlPromptBar: View {
    @Binding var prompt: Actions.ControlPrompt
    let focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onCancel: () -> KeyPress.Result

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Iconography.icon(for: prompt.ref)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22, alignment: .center)

            Text(prompt.ref.descriptor.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            TextField("Arguments", text: $prompt.arguments)
                .foregroundStyle(.primary)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .focused(focused)
                .onKeyPress(.return) { onSubmit(); return .handled }
                .onKeyPress(.escape) { onCancel() }

            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SearchRow: View {
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
                    Iconography.icon(for: ref)
                        .font(.system(size: 12, weight: .medium))
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

                if let description = item.description, !description.isEmpty {
                    Text(description)
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

struct SearchInput: View {
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

struct SearchContent: View {
    @Binding var index: Int
    let params: Parameters
    let onTap: (ItemParams) -> Void
    var flatItems: [ItemParams] { params.sections.flatMap { $0.items } }
    var isEmpty: Bool { flatItems.isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) { if isEmpty { empty } else { content } }
                    .padding(.horizontal, 8)
                    .onChange(of: index) {
                        guard flatItems.indices.contains(index) else { return }
                        proxy.scrollTo(flatItems[index].id, anchor: .center)
                    }
            }
        }
    }

    var content: some View {
        ForEach(params.sections) { section in sectionView(section, startIndex: runningIndexBefore(section)) }
            .id(params.sections.map(\.id))
    }

    var empty: some View {
        VStack {
            Text("No results")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    func runningIndexBefore(_ section: ListParams) -> Int {
        var count = 0
        for s in params.sections {
            if s.id == section.id { return count }
            count += s.items.count
        }
        return count
    }

    @ViewBuilder func sectionView(_ section: ListParams, startIndex: Int) -> some View {
        if section.header && !section.name.isEmpty {
            Text(section.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 6)
        }

        ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, item in
            let absolute = startIndex + offset
            SearchRow(
                item: item,
                isSelected: absolute == index,
                onTap: {
                    index = absolute
                    onTap(item)
                }
            )
            .id(item.id)
        }
    }
}

struct SearchView: View {
    @Environment(AgencyModel.self) var agency
    @FocusState private var focused: Bool
    private var params: Parameters { agency.studio.actions.parameters(agency) }
    private var flatItems: [ItemParams] { params.sections.flatMap { $0.items } }

    var body: some View {
        @Bindable var search = agency.studio.actions

        VStack(alignment: .leading, spacing: 0) {
            if let _ = agency.studio.actions.prompt {
                ControlPromptBar(
                    prompt: Binding(
                        get: { agency.studio.actions.prompt ?? .init(ref: flatItems[agency.studio.actions.index].ref!) },
                        set: { agency.studio.actions.prompt = $0 }
                    ),
                    focused: $focused,
                    onSubmit: { },
                    onCancel: { closePrompt(); return .handled }
                )
            } else {
                SearchInput(
                    query: $search.query,
                    image: agency.studio.actions.model.image,
                    placeholder: agency.studio.actions.model.placeholder,
                    focused: $focused,
                    onUpArrow: { move(-1); return .handled },
                    onDownArrow: { move(+1); return .handled },
                    onReturn: { activate(); return .handled },
                    onTab: { showAuxiliary(); return .handled }
                )
                SearchContent(
                    index: $search.index,
                    params: params,
                    onTap: { _ in activate() }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .onChange(of: agency.studio.actions.query) { _, _ in agency.studio.actions.index = 0 }
        .onChange(of: agency.studio.actions.model) { _, _ in agency.studio.actions.reset(); focused = true }
        .background {
            ZStack {
                Button { agency.studio.actions.model = .commands } label: { EmptyView() }
                    .keyboardShortcut("1", modifiers: .command)
                Button { agency.studio.actions.model = .interfaces } label: { EmptyView() }
                    .keyboardShortcut("2", modifiers: .command)
                Button { agency.studio.actions.model = .library } label: { EmptyView() }
                    .keyboardShortcut("3", modifiers: .command)
                Button { agency.studio.actions.model = .workspace } label: { EmptyView() }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private func move(_ delta: Int) {
        let count = flatItems.count
        guard count > 0 else { return }
        agency.studio.actions.index = (agency.studio.actions.index + delta + count) % count
    }

    private func activate() {
        guard flatItems.indices.contains(agency.studio.actions.index) else { return }
        let item = flatItems[agency.studio.actions.index]

        if let ref = item.ref, ref.type is Command.Type {
            agency.studio.actions.prompt = .init(ref: ref)
            focused = true
            return
        }

        agency.studio.actions.controls(agency).onSelect?(item)
        dismiss()
    }

    private func showAuxiliary() {
        guard flatItems.indices.contains(agency.studio.actions.index) else { return }
        guard let ref = flatItems[agency.studio.actions.index].ref else { return }

        if ref.type is Command.Type {
            agency.studio.actions.prompt = .init(ref: ref)
            focused = true
            return
        }
    }

    private func closePrompt() {
        agency.studio.actions.prompt = nil; focused = true
    }

    private func showDetails() {
        guard flatItems.indices.contains(agency.studio.actions.index) else { return }
    }

    private func closeDetails() {
        focused = true
    }

    private func dismiss() {
        agency.studio.actions.reset(); agency.panels.panels["search"]?.hide()
    }
}

@Observable final class Actions: Panel {
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []
    var index: Int = 0
    var query: String = ""
    var prompt: ControlPrompt?

    struct ControlPrompt: Hashable {
        let ref: Reference
        var arguments: String = ""
    }

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

    func parameters(_ agency: AgencyModel) -> Parameters { .init() }

    func reset() {
        query = ""
        index = 0
    }
}
