import AppKit
import Observation
import SwiftUI
import OrderedCollections
import AgencyRuntime


struct ActionsIndexComponent: Identifiable {
    let component: ComponentParams
    let startIndex: Int

    var id: AnyHashable { component.id }

    static func index(_ components: [ComponentParams]) -> [ActionsIndexComponent] {
        var offset = 0
        return components.map { component in
            defer { offset += component.items.count }
            return ActionsIndexComponent(component: component, startIndex: offset)
        }
    }
}

struct ActionsComponent: View {
    let component: ComponentParams
    let startIndex: Int
    let selectedIndex: Int
    let controls: Controls
    let onSelectIndex: (Int) -> Void

    var body: some View {
        if !component.items.isEmpty {
            if component.header && !component.name.isEmpty {
                Text(component.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
            }

            ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                let absoluteIndex = startIndex + offset
                ActionsRow(
                    item: item,
                    isSelected: absoluteIndex == selectedIndex,
                    onTap: {
                        onSelectIndex(absoluteIndex)
                        controls.onSelect?(item)
                    }
                )
                .id(item.id)
            }
        }
    }
}

struct ActionsInput: View {
    @Binding var query: String
    @FocusState private var focused: Bool
    let image: String
    let placeholder: String
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: image)
                    .frame(height: 48, alignment: .center)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $query)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 28, weight: .light))
                    .textFieldStyle(.plain)
                    .onKeyPress(.upArrow) { onUpArrow() }
                    .onKeyPress(.downArrow) { onDownArrow() }
                    .onKeyPress(.return) { onReturn() }
                    .onKeyPress(.tab) { onTab() }
                    .focused($focused)
            }
            .frame(height: 48)
            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .padding(.horizontal, 4)
                .opacity(0.17)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .onAppear { focused = true }
        .onChange(of: placeholder) { _, _ in focused = true }
    }
}

struct ActionsRow: View {
    let item: ItemParams
    let isSelected: Bool
    let onTap: () -> Void

    @ViewBuilder private var icon: some View {
        if let ref = item.ref {
            Iconography.Icon(
                symbol: Iconography.symbol(for: ref),
                tint: Iconography.accent(for: ref),
                sizing: 20,
                selected: isSelected
            )
        } else {
            Iconography.Icon(
                symbol: item.image.isEmpty ? "square.stack.3d.up" : item.image,
                tint: Design.Tint.active,
                sizing: 20,
                selected: isSelected
            )
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            icon
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected ?
                        Design.Foreground.primary :
                        Design.Foreground.secondary
                    )
                    .lineLimit(1)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .padding(.trailing, 8)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isSelected ?
                Design.Foreground.quaternary.opacity(0.3) : Color.clear)
        )
    }
}

struct ActionsPanelContent: View {
    @Binding var query: String
    @Binding var selectedIndex: Int
    let model: Actions.Model
    let params: Params
    let controls: Controls
    var onCycleModel: () -> Void = {}
    var onCommitSelection: () -> Void = {}

    var body: some View {
        let flatItems = params.components.flatMap { $0.items }

        func move(_ delta: Int) {
            let count = flatItems.count
            guard count > 0 else { return }
            selectedIndex = (selectedIndex + delta + count) % count
        }

        func action() {
            guard flatItems.indices.contains(selectedIndex) else { return }
            controls.onSelect?(flatItems[selectedIndex])
            onCommitSelection()
        }

        return VStack(alignment: .leading, spacing: 0) {
            ActionsInput(
                query: $query,
                image: model.image,
                placeholder: model.placeholder,
                onUpArrow: { move(-1); return .handled },
                onDownArrow: { move(+1); return .handled },
                onReturn: { action(); return .handled },
                onTab: { onCycleModel(); return .handled }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(ActionsIndexComponent.index(params.components)) { indexed in
                            ActionsComponent(
                                component: indexed.component,
                                startIndex: indexed.startIndex,
                                selectedIndex: selectedIndex,
                                controls: controls,
                                onSelectIndex: { selectedIndex = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    guard flatItems.indices.contains(newIndex) else { return }
                    proxy.scrollTo(flatItems[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionsLayout: View {
    @Environment(AgencyModel.self) var agency
    var actions: Actions { agency.studio.actions }

    var body: some View {
        let _ = actions.queryRevision
        let controls = actions.controls(agency)
        let params = actions.parameters(agency)

        func dismiss() {
            actions.reset()
            agency.panels.panels["panel"]?.hide()
        }

        return ActionsPanelContent(
            query: Binding(
                get: { actions.query },
                set: { actions.setQuery($0) }
            ),
            selectedIndex: Binding(
                get: { actions.index },
                set: { actions.index = $0 }
            ),
            model: actions.model,
            params: params,
            controls: controls,
            onCycleModel: { actions.cycleModel() },
            onCommitSelection: { dismiss() }
        )
        .onChange(of: actions.model) { _, _ in actions.reset() }
        .background {
            ZStack {
                Button { actions.model = .commands } label: { EmptyView() }
                    .keyboardShortcut("1", modifiers: .command)
                Button { actions.model = .interfaces } label: { EmptyView() }
                    .keyboardShortcut("2", modifiers: .command)
                Button { actions.model = .library } label: { EmptyView() }
                    .keyboardShortcut("3", modifiers: .command)
                Button { actions.model = .workspace } label: { EmptyView() }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }
}

@Observable @MainActor final class Actions: Panel {
    @ObservationIgnored var query = ""
    var state = SurfaceState()
    var queryRevision = 0
    var model: Model = .commands
    var position: CGFloat = 0
    var presented: Bool = true
    var index: Int = 0

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { label }

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

    func parameters(_ agency: AgencyModel) -> Params {
        switch model {
            case .commands: SearchMap.parameters(agency)
            case .interfaces: InterfacesMap.parameters(agency)
            case .library: ComponentsMap.parameters(agency)
            case .workspace: StructuresMap.parameters(agency)
        }
    }

    func setQuery(_ value: String) {
        guard query != value else { return }
        query = value
        queryRevision += 1
        index = 0
    }

    func reset() {
        query = ""
        queryRevision += 1
        index = 0
    }

    func cycleModel() {
        let modes = Model.allCases
        guard let current = modes.firstIndex(of: model) else { return }
        model = modes[(current + 1) % modes.count]
    }

    func view(_ agency: AgencyModel) -> some View { ActionsLayout() }
}

private struct ActionsPanelPreview: View {
    @State private var query = ""
    @State private var selectedIndex = 2
    @State private var model: Actions.Model = .commands

    private var params: Params {
        let components: [ComponentParams] = Self.components(for: model).compactMap { component -> ComponentParams? in
            let items = filtered(component.items)
            guard !items.isEmpty else { return nil }
            return ComponentParams(
                id: component.id.description,
                name: component.name,
                header: component.header,
                image: component.image,
                tint: component.tint,
                items: items
            )
        }

        return Params(nesting: .flat, components: components)
    }

    var body: some View {
        ActionsPanelContent(
            query: $query,
            selectedIndex: $selectedIndex,
            model: model,
            params: params,
            controls: .init(onSelect: { _ in }),
            onCycleModel: cycleModel
        )
        .frame(width: 520, height: 620)
        .background(Design.Background.actions)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    private func cycleModel() {
        let models = Actions.Model.allCases
        guard let index = models.firstIndex(of: model) else { return }
        model = models[(index + 1) % models.count]
        selectedIndex = 0
        query = ""
    }

    private func filtered(_ items: [ItemParams]) -> [ItemParams] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return items }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(normalizedQuery) ||
            item.description.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private static func components(for model: Actions.Model) -> [ComponentParams] {
        switch model {
            case .commands:
                [
                    .init(
                        id: "commands",
                        header: false,
                        items: [
                            .init(name: "Open Selection", image: "arrow.up.forward.app", description: "Reveal the selected artifact or sheet"),
                            .init(name: "Run Current Space", image: "play.fill", description: "Start a new process from this space"),
                            .init(name: "Create Sheet", image: "text.badge.plus", description: "Add a fresh working note"),
                            .init(name: "Attach File", image: "paperclip", description: "Register a file artifact"),
                            .init(name: "Archive Completed Runs", image: "archivebox", description: "Clean up finished process history")
                        ]
                    )
                ]
            case .interfaces:
                [
                    .init(
                        id: "artifacts",
                        name: "Artifacts",
                        items: [
                            .init(name: "Design.sketch", image: "doc", description: "Local Sketch document"),
                            .init(name: "Product Brief", image: "text.page", description: "Markdown brief artifact"),
                            .init(name: "Preview Validation", image: "checkmark.seal", description: "Validation report")
                        ]
                    ),
                    .init(
                        id: "controls",
                        name: "Controls",
                        items: [
                            .init(name: "Generate Options", image: "switch.2", description: "Command"),
                            .init(name: "Summarize Context", image: "switch.2", description: "Command")
                        ]
                    )
                ]
            case .library:
                [
                    .init(
                        id: "sheets",
                        name: "Sheets",
                        items: [
                            .init(name: "Launch Notes", image: "text.alignleft", description: "12 blocks"),
                            .init(name: "Prompt Experiments", image: "text.alignleft", description: "8 blocks"),
                            .init(name: "Implementation Checklist", image: "checklist", description: "6 tasks")
                        ]
                    ),
                    .init(
                        id: "transcripts",
                        name: "Transcripts",
                        items: [
                            .init(name: "Actions Panel Tuning", image: "rectangle.stack", description: "Completed run"),
                            .init(name: "Dashboard Prototype", image: "rectangle.stack", description: "Blocked run")
                        ]
                    )
                ]
            case .workspace:
                [
                    .init(
                        id: "workspace",
                        name: "Workspace",
                        items: [
                            .init(name: "Agency Studio", image: "cube.transparent", description: "Current workspace"),
                            .init(name: "Runtime Migration", image: "space.badge.play", description: "Active process space"),
                            .init(name: "Design Review", image: "space.badge.eye", description: "Observation space")
                        ]
                    )
                ]
        }
    }
}

#Preview("Actions Panel") {
    ActionsPanelPreview()
}
