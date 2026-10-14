import SwiftUI
import ScintRuntime
import ScintComponents


private func handled(_ press: KeyPress, _ onInput: ((Controls.Input) -> Bool)?) -> KeyPress.Result {
    let input: Controls.Input? = switch press.key {
        case .upArrow: .move(-1)
        case .downArrow: .move(1)
        case .return: .submit
        case .tab: .secondary
        case .escape: .cancel
        default: nil
    }
    return input.flatMap { onInput?($0) } == true ? .handled : .ignored
}

struct PanelAnchor: NSViewRepresentable {
    final class Box { var view: NSView? }
    let box: Box

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView()
        box.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Self.Context) { box.view = view }
}

struct PanelShortcuts: View {
    let count: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            ForEach(0..<min(count, 9), id: \.self) { index in
                Button { onSelect(index) } label: { EmptyView() }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
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

struct PanelField: View {
    @Environment(\.controlSize) private var controlSize
    @Binding var text: String
    @FocusState private var focused: Bool
    let field: ItemParams
    let onInput: ((Controls.Input) -> Bool)?

    var compact: Bool { controlSize == .small }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: compact ? 8 : 16) {
                Image(systemName: field.image)
                    .foregroundStyle(field.tint ?? (compact ? Style.Foreground.secondary : Style.Foreground.primary))
                    .font(.system(size: compact ? 13 : 26, weight: compact ? .regular : .light))

                TextField(field.name, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Style.Foreground.primary)
                    .font(.system(size: compact ? 13 : 28, weight: compact ? .regular : .light))
                    .padding(.bottom, compact ? 0 : 2)
                    .focused($focused)
                    .onKeyPress(keys: [.upArrow, .downArrow, .return, .tab, .escape]) { handled($0, onInput) }
            }
            .frame(height: compact ? 30 : 48)

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: compact ? 0.5 : 0.6)
                .padding(.horizontal, 4)
                .opacity(compact ? 0.17 : 0.33)
        }
        .padding(.horizontal, compact ? 12 : 22)
        .padding(.vertical, compact ? 2 : 8)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onChange(of: field.name) { _, _ in DispatchQueue.main.async { focused = true } }
    }
}

struct PanelReference: View {
    let ref: Reference

    init(_ ref: Reference) { self.ref = ref }

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
        }
    }
}

struct PanelModes: View {
    let tabs: [SectionParams]
    let active: AnyHashable?
    let onSelect: (SectionParams) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(tabs) { tab in
                Button { onSelect(tab) } label: {
                    HStack(spacing: 5) {
                        if !tab.image.isEmpty { Image(systemName: tab.image).font(.system(size: 10)) }
                        Text(tab.name).font(.system(size: 11, weight: tab.id == active ? .medium : .regular))
                    }
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Style.Shape.panel)
                    .background(Style.Shape.panel.fill(tab.id == active ? Style.Background.selection : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }
}

struct PanelRow: View {
    @Environment(\.controlSize) private var controlSize
    let item: ItemParams
    let active: Bool
    let selected: Bool
    let onTap: () -> Void

    var compact: Bool { controlSize == .small }

    var body: some View {
        let size = compact ? Metrics.rowIcon : 20
        let shape = compact ? AnyShape(Style.Shape.button) : AnyShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

        HStack(alignment: .center, spacing: 0) {
            Group {
                if let ref = item.ref { Iconography.icon(for: ref, size: size) }
                else { Iconography.Icon(symbol: item.image.isEmpty ? "square.stack.3d.up" : item.image, tint: item.tint ?? Style.Tint.neutral.bright, sizing: size, selected: active) }
            }
            .frame(width: compact ? 20 : 34, height: compact ? 20 : 34)
            .saturation(compact && !active ? 0 : 1)
            .opacity(compact && !active ? Style.Opacity.pressed : 1)
            .padding(.leading, compact ? 8 : 4)
            .padding(.trailing, compact ? 4 : 8)

            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                Text(item.name)
                    .font(.system(size: compact ? 13 : 16, weight: !compact && active ? .medium : .regular))
                    .foregroundStyle(Style.Foreground.primary)
                    .lineLimit(1)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: compact ? 11 : 12.5))
                        .foregroundStyle(Style.Foreground.subtle)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if compact, selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Style.Foreground.secondary)
                    .padding(.trailing, 8)
            } else if !compact, active {
                Image(systemName: "return")
                    .font(.system(size: 13))
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(.trailing, 8)
            }
        }
        .padding(.vertical, compact ? 4 : 8)
        .padding(.horizontal, compact ? 0 : 12)
        .frame(minHeight: compact ? 28 : nil)
        .background(shape.fill(active || (!compact && selected) ? Style.Background.selection : Color.clear))
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: active)
        .padding(.horizontal, compact ? 0 : 8)
    }
}

struct PanelLayout<Header: View, Content: View>: View {
    @Environment(\.controlSize) private var controlSize
    @FocusState private var focused: Bool
    let size: CGSize
    let focusable: Bool
    let current: AnyHashable?
    let onInput: ((Controls.Input) -> Bool)?
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var compact: Bool { controlSize == .small }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 13 : Style.Shape.frameRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            header()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 4 : 2) { content() }
                        .padding(compact ? 5 : 4)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .onChange(of: current) { _, current in
                    guard let current else { return }
                    withAnimation(Metrics.menuSelection) { proxy.scrollTo(current, anchor: .center) }
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .focusable(focusable)
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow, .return, .tab, .escape]) { handled($0, onInput) }
        .onAppear { DispatchQueue.main.async { focused = focusable } }
        .clipShape(shape)
        .glassEffect(.regular, in: shape)
        .overlay { if !compact { shape.strokeBorder(.black.opacity(Style.Opacity.border), lineWidth: 0.5) } }
    }
}
