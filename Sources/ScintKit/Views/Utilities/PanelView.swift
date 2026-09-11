import SwiftUI


private struct PanelCursorKey: EnvironmentKey { nonisolated(unsafe) static let defaultValue: AnyHashable? = nil }

extension EnvironmentValues {
    var panelCursor: AnyHashable? {
        get { self[PanelCursorKey.self] }
        set { self[PanelCursorKey.self] = newValue }
    }
}

extension PanelState {
    var cursor: AnyHashable? {
        get { self["cursor", as: AnyHashable.self] }
        set { self["cursor", as: AnyHashable.self] = newValue }
    }
}

struct PanelInput: View {
    @Binding var value: String
    @FocusState var focused: Bool

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
                    .foregroundStyle(Style.Foreground.faint)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $value)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Style.Foreground.faint)
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

struct PanelHeader: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

struct PanelModes: View {
    let items: [ItemParams]
    let selection: ItemParams?
    let onSelect: (ItemParams) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let active = item.id == selection?.id

                Button { onSelect(item) } label: {
                    HStack(spacing: 5) {
                        if !item.image.isEmpty {
                            Image(systemName: item.image)
                                .font(.system(size: 10))
                        }
                        Text(item.name)
                            .font(.system(size: 11, weight: active ? .medium : .regular))
                    }
                    .foregroundStyle(active ? Style.Foreground.primary : Style.Foreground.faint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Style.Shape.panel)
                    .background(
                        Style.Shape.panel
                            .fill(active ? Color.accentColor.opacity(0.4) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

struct PanelRow: View {
    @Environment(\.panelCursor) private var cursor

    let params: ItemParams
    let selected: Bool
    let onTap: () -> Void

    private var active: Bool { cursor == params.id || selected }

    var body: some View {
        GroupRow(
            title: Text(params.name)
                .font(.system(size: 16, weight: active ? .medium : .regular))
                .foregroundColor(
                    active
                    ? Style.Foreground.primary
                    : Style.Foreground.secondary
                ),
            detail: params.description.isEmpty ? nil : Text(params.description)
                .font(.system(size: 13))
                .foregroundColor(Style.Foreground.faint)
        ) {
            Iconography.Icon(
                symbol: params.image.isEmpty ? "square.stack.3d.up" : params.image,
                tint: params.tint ?? Style.Tint.space,
                sizing: 20,
                selected: active
            )
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)
        } trailing: {
            if active {
                Image(systemName: "return")
                    .padding(.trailing, 8)
                    .font(.system(size: 13))
                    .foregroundStyle(Style.Foreground.faint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: active)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    active
                    ? Color.accentColor.opacity(0.6)
                    : Color.clear
                )
        )
    }
}

struct PanelDetail<Content: View>: View {
    let params: Params
    let content: Content

    init(params: Params, @ViewBuilder content: () -> Content) {
        self.params = params
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let ref = params.ref { Iconography.icon(for: ref, size: 22) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(params.name)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)

                    if !params.description.isEmpty {
                        Text(params.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Style.Foreground.faint)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text("esc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Style.Foreground.faint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Style.Shape.panel.fill(.tertiary.opacity(0.25)))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .padding(.horizontal, 4)
                .opacity(0.17)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) { content }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
            .scrollEdgeEffectStyle(.hard, for: .vertical)
        }
    }
}

struct PanelPin: View {
    let pinned: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: pinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(pinned ? Style.Foreground.primary : Style.Foreground.faint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(pinned ? "Unpin" : "Pin")
        .padding(8)
    }
}

struct PanelShortcuts: View {
    let count: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            ForEach(0..<min(count, 9), id: \.self) { index in
                Button { onSelect(index) } label: { EmptyView() }
                    .keyboardShortcut(
                        KeyEquivalent(Character(String(index + 1))),
                        modifiers: .command
                    )
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

struct PanelView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity)
    }
}
