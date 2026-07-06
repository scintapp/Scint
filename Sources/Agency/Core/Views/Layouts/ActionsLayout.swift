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
    let image: String
    let placeholder: String
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: image)
                .foregroundStyle(.secondary.opacity(0.8))
                .font(.system(size: 24))

            TextField(placeholder, text: $query)
                .foregroundStyle(.primary)
                .font(.system(size: 26))
                .textFieldStyle(.plain)
                .onKeyPress(.upArrow) { onUpArrow() }
                .onKeyPress(.downArrow) { onDownArrow() }
                .onKeyPress(.return) { onReturn() }
                .onKeyPress(.tab) { onTab() }
                .focused($focused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                sizing: 16,
                selected: isSelected
            )
        } else {
            Iconography.Icon(
                symbol: item.image.isEmpty ? "square.stack.3d.up" : item.image,
                tint: Design.Tint.active,
                sizing: 16,
                selected: isSelected
            )
        }
    }

    var body: some View {
        HStack {
            icon
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.96) : Color.primary.opacity(0.84))
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
                .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
        )
    }
}

struct ActionsPanelView: View {
    let actions: Actions
    let agency: AgencyModel

    var body: some View {
        let _ = actions.queryRevision
        let controls = actions.controls(agency)
        let params = actions.parameters(agency)
        let flatItems = params.components.flatMap { $0.items }

        func move(_ delta: Int) {
            let count = flatItems.count
            guard count > 0 else { return }
            actions.index = (actions.index + delta + count) % count
        }

        func action() {
            guard flatItems.indices.contains(actions.index) else { return }
            controls.onSelect?(flatItems[actions.index])
            dismiss()
        }

        func dismiss() {
            actions.reset()
            agency.panels.panels["panel"]?.hide()
        }

        return VStack(alignment: .leading, spacing: 0) {
            ActionsInput(
                query: Binding(
                    get: { actions.query },
                    set: { actions.setQuery($0) }
                ),
                image: actions.model.image,
                placeholder: actions.model.placeholder,
                onUpArrow: { move(-1); return .handled },
                onDownArrow: { move(+1); return .handled },
                onReturn: { action(); return .handled },
                onTab: { actions.cycleModel(); return .handled }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(ActionsIndexComponent.index(params.components)) { indexed in
                            ActionsComponent(
                                component: indexed.component,
                                startIndex: indexed.startIndex,
                                selectedIndex: actions.index,
                                controls: controls,
                                onSelectIndex: { actions.index = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: actions.index) { _, newIndex in
                    guard flatItems.indices.contains(newIndex) else { return }
                    proxy.scrollTo(flatItems[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
