import SwiftUI
import ScintRuntime
import ScintComponents


extension PanelState {
    var cursor: Reference? {
        get { self["cursor", as: Reference.self] }
        set { self["cursor", as: Reference.self] = newValue }
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
                    .foregroundStyle(Style.Foreground.primary)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $value)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Style.Foreground.primary)
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
                .frame(maxWidth: .infinity, maxHeight: 0.6)
                .padding(.horizontal, 4)
                .opacity(0.33)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .padding(.top, 6)
    }
}

struct PanelModes: View {
    let modes: [(label: String, image: String)]
    let selection: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(modes.indices, id: \.self) { index in
                let mode = modes[index]
                let active = index == selection

                Button { onSelect(index) } label: {
                    HStack(spacing: 5) {
                        if !mode.image.isEmpty {
                            Image(systemName: mode.image)
                                .font(.system(size: 10))
                        }
                        Text(mode.label)
                            .font(.system(size: 11, weight: active ? .medium : .regular))
                    }
                    .foregroundStyle(active ? Style.Foreground.primary : Style.Foreground.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Style.Shape.panel)
                    .background(
                        Style.Shape.panel
                            .fill(active ? Style.Background.selection : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 6)
    }
}

struct PanelRow: View {
    let name: String
    var description: String = ""
    var image: String = ""
    var tint: Color? = nil
    var active: Bool = false
    let onTap: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Iconography.Icon(
                    symbol: image.isEmpty ? "square.stack.3d.up" : image,
                    tint: tint ?? Style.Foreground.primary,
                    sizing: 20,
                    selected: active
                )
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 4)
                .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                    Text(name)
                        .font(.system(size: 16, weight: active ? .medium : .regular))
                        .foregroundColor(Style.Foreground.primary)
                        .lineLimit(1)
                        .frame(height: 12)

                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12.5))
                            .foregroundColor(Style.Foreground.subtle)
                            .lineLimit(1)
                            .frame(height: 10)
                    }
                }

                Spacer()

                if active {
                    Image(systemName: "return")
                        .padding(.trailing, 8)
                        .font(.system(size: 13))
                        .foregroundStyle(Style.Foreground.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .animation(.easeOut(duration: 0.1), value: active)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        active
                        ? Style.Background.selection
                        : Color.clear
                    )
            )
        }
        .padding(.horizontal, 8)
    }
}

struct PanelDetail<Content: View>: View {
    let ref: Reference
    let content: Content

    init(_ ref: Reference, @ViewBuilder content: () -> Content) {
        self.ref = ref
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Iconography.icon(for: ref, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ref.descriptor.name)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)

                    if !ref.descriptor.description.isEmpty {
                        Text(ref.descriptor.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text("esc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Style.Shape.panel.fill(.tertiary))
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
                .foregroundStyle(pinned ? Style.Foreground.primary : Style.Foreground.primary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
