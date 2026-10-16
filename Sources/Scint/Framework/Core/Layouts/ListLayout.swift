import SwiftUI
import ScintRuntime
import ScintComponents


struct ListLabel: View {
    let name: String
    let image: String
    var tint: Color
    var detail: String?

    init(_ name: String, image: String, tint: Color = .secondary, detail: String? = nil) {
        self.name = name
        self.image = image
        self.tint = tint
        self.detail = detail
    }

    var body: some View {
        HStack {
            Image(systemName: image)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.82))
                .frame(width: 25, height: 25)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.opacity(0.12)))
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct ListLink: View {
    @State private var isHovered = false
    private let iconSize: CGFloat = 16
    let ref: Reference?
    let name: String
    let detail: String?
    let image: String
    let tint: Color
    let trailingImage: String?
    let count: Int?
    let leadingAccessory: AnyView?
    let accessory: AnyView?
    let indent: CGFloat
    let selected: Bool
    let focused: Bool
    let onSelect: () -> Void

    init(name: String, detail: String? = nil, ref: Reference? = nil, image: String, tint: Color? = nil,
         trailingImage: String? = nil, count: Int? = nil, leadingAccessory: AnyView? = nil,
         accessory: AnyView? = nil, indent: CGFloat = 0,
         selected: Bool = false, focused: Bool = true, onSelect: @escaping () -> Void) {

        self.name = name
        self.detail = detail
        self.ref = ref
        self.image = image
        self.tint = tint ?? Style.Foreground.glyph
        self.trailingImage = trailingImage
        self.count = count
        self.leadingAccessory = leadingAccessory
        self.accessory = accessory
        self.indent = indent
        self.selected = selected
        self.focused = focused
        self.onSelect = onSelect
    }

    @ViewBuilder private var icon: some View {
        Iconography.icon(symbol: image, tint: tint, ref: ref, size: image == Iconography.dotSymbol ? iconSize * Iconography.dotScale : iconSize, selected: selected)
            .fontWeight(.medium)
            .frame(width: iconSize, height: iconSize)
    }

    @ViewBuilder private var leading: some View {
        ZStack {
            icon
                .opacity(isHovered && leadingAccessory != nil ? 0 : 1)

            if let leadingAccessory {
                leadingAccessory
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)
            }
        }
        .frame(width: iconSize, height: iconSize, alignment: .center)
        .padding(.trailing, 4)
        .padding(.leading, 2)
    }

    var body: some View {
        Button(action: onSelect) {
            ListRow(
                name: name, detail: detail, accessory: accessory, trailingImage: trailingImage, count: count,
                selected: selected, focused: focused) {
                    HStack {
                        if indent > 0 { Color.clear.frame(width: indent - 8) }
                        leading
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }

    }
}

struct ListRow<Content: View>: View {
    let name: String
    let detail: String?
    let accessory: AnyView?
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let selected: Bool
    let focused: Bool
    let content: Content

    init(
        name: String, detail: String? = nil, accessory: AnyView? = nil,
        trailingImage: String? = nil, count: Int? = nil,
        indent: CGFloat = 0, selected: Bool = false, focused: Bool = true,
        @ViewBuilder leading: () -> Content) {
            self.name = name
            self.detail = detail
            self.accessory = accessory
            self.count = count
            self.indent = indent
            self.selected = selected
            self.focused = focused
            self.trailingImage = trailingImage
            self.content = leading()
        }

    private var described: String? {
        guard let detail, !detail.isEmpty else { return nil }
        return detail
    }

    private var background: Color {
        guard selected else { return .clear }
        return focused ? Style.Tint.accent.bright.opacity(0.5) : Style.Background.selection.opacity(Style.Opacity.outline)
    }

    var body: some View {
        HStack(alignment: .center) {
            Color.clear.frame(width: indent)
            content

            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let described {
                    Text(described)
                        .font(Typography.detail)
                        .foregroundColor(Style.Foreground.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let accessory { accessory.padding(.trailing, 8) }
            if let trailingImage { Image(systemName: trailingImage).font(.system(size: 12)) }

            if let count {
                Text("\(count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 24)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 7).fill(background))
        .foregroundStyle(.primary)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ListHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    let name: String
    let expanded: Bool
    let onAdd: (() -> Void)?
    let onToggle: (() -> Void)?

    init(name: String, expanded: Bool = true, onAdd: (() -> Void)? = nil, onToggle: (() -> Void)? = nil) {
        self.name = name
        self.expanded = expanded
        self.onAdd = onAdd
        self.onToggle = onToggle
    }

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.bottom, 6)

            if let onToggle {
                Spacer()

                Button { withAnimation(reduceMotion ? nil : .default, onToggle) } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 12, height: 12)
                        .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .contentShape(RoundedRectangle(cornerRadius: 10.0))
        .onHover { isHovered = $0 }
    }
}

struct ListLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    private let iconSize: CGFloat = 16
    let ref: Reference?
    let name: String
    let detail: String?
    let image: String
    let tint: Color
    let trailingImage: String?
    let count: Int?
    let leadingAccessory: AnyView?
    let accessory: AnyView?
    let indent: CGFloat
    let isExpanded: Bool
    let selected: Bool
    let focused: Bool
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void
    let rowWrapper: (AnyView) -> AnyView

    init(
        name: String,
        detail: String? = nil,
        ref: Reference? = nil,
        image: String,
        tint: Color? = nil,
        trailingImage: String? = nil,
        count: Int? = nil,
        leadingAccessory: AnyView? = nil,
        accessory: AnyView? = nil,
        indent: CGFloat = 0,
        isExpanded: Bool = false,
        selected: Bool = false,
        focused: Bool = true,
        onSelect: @escaping () -> Void,
        onToggleExpanded: @escaping () -> Void,
        rowWrapper: @escaping (AnyView) -> AnyView = { $0 },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.detail = detail
        self.ref = ref
        self.image = image
        self.tint = tint ?? Style.Foreground.glyph
        self.trailingImage = trailingImage
        self.count = count
        self.leadingAccessory = leadingAccessory
        self.accessory = accessory
        self.indent = indent
        self.isExpanded = isExpanded
        self.selected = selected
        self.focused = focused
        self.onSelect = onSelect
        self.onToggleExpanded = onToggleExpanded
        self.rowWrapper = rowWrapper
        self.content = content
    }

    @ViewBuilder private var icon: some View {
        Iconography.icon(symbol: image, tint: tint, ref: ref, size: image == Iconography.dotSymbol ? iconSize * Iconography.dotScale : iconSize, selected: selected)
            .fontWeight(.medium)
            .frame(width: iconSize, height: iconSize)
    }

    @ViewBuilder private var hoverLeading: some View {
        if let leadingAccessory {
            leadingAccessory
        } else {
            Button(role: nil, action: { withAnimation(reduceMotion ? nil : .default, onToggleExpanded) }) {
                let size = iconSize * 1.25
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.tertiary.opacity(0.3))
                        .frame(width: size, height: size, alignment: .center)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: size, height: size, alignment: .center)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: size, height: size, alignment: .center)
                .padding(.trailing, 4)
                .padding(.leading, 2)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        let row = AnyView(
            Button(role: nil, action: onSelect) {
                ListRow(name: name, detail: detail, accessory: accessory, trailingImage: trailingImage, count: count, indent: indent, selected: selected, focused: focused) {
                    ZStack {
                        hoverLeading
                            .opacity(isHovered ? 1 : 0)
                            .allowsHitTesting(isHovered)

                        icon
                            .opacity(isHovered ? 0 : 1)
                    }
                    .frame(width: iconSize, height: iconSize, alignment: .center)
                    .padding(.trailing, 4)
                    .padding(.leading, 2)
                }
            }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
        )

        rowWrapper(row)
        if isExpanded { content() }
    }
}
