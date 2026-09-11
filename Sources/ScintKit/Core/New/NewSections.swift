import SwiftUI


/// Generic containers and styles for the sketch factory.
///
/// These carry chrome, metrics and interaction. They take plain values and a content closure;
/// what goes inside is composed by the factory, so no view here corresponds one-to-one with a
/// param case. Every number is ported from the tuned originals — `ListRow`, `GroupRow`,
/// `GroupLayout`, `ListLayout` — so the two paths render the same.
///
/// Row metrics differ by the scaffolding a row sits in rather than by anything params describe,
/// so the containers publish it through the environment instead of the factory plumbing it down.
enum NewRowStyle {
    /// A tree row: grows with its content, no inset, list typography.
    case list
    /// A row inside a group container: fixed height, inset, heavier typography.
    case group
    /// A label above a list — ported from `ListHeader`.
    case listHeader
    /// A label above a group container — ported from `GroupLayout`.
    case groupHeader
}

extension EnvironmentValues {
    @Entry var newRowStyle: NewRowStyle = .list
    @Entry var newRowHovered: Bool = false
}

// MARK: - Text

struct NewTitleStyle: ViewModifier {
    @Environment(\.newRowStyle) private var style

    private var font: Font {
        switch style {
            case .list: .system(size: 13)
            case .group: .system(size: 13, weight: .semibold)
            case .listHeader: .system(size: 11)
            case .groupHeader: .system(size: 11, weight: .semibold)
        }
    }

    private var color: Color {
        switch style {
            case .list: .primary
            case .group: .primary.opacity(0.88)
            case .listHeader: .secondary.opacity(0.7)
            case .groupHeader: .secondary.opacity(0.75)
        }
    }

    func body(content: Self.Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .lineLimit(Style.Limit.singleLine)
    }
}

struct NewDetailStyle: ViewModifier {
    @Environment(\.newRowStyle) private var style

    private var font: Font {
        switch style {
            case .list, .listHeader, .groupHeader: Typography.caption
            case .group: .system(size: 11, weight: .medium)
        }
    }

    private var color: Color {
        switch style {
            case .list, .listHeader, .groupHeader: Style.Foreground.faint
            case .group: .secondary.opacity(0.72)
        }
    }

    private var lines: Int {
        switch style {
            case .list, .listHeader, .groupHeader: Style.Limit.singleLine
            case .group: Style.Limit.singleLine
        }
    }

    func body(content: Self.Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lines)
    }
}

// MARK: - Rows

struct NewRow<Content: View>: View {
    @Environment(\.newRowStyle) private var style
    @State private var hovered = false

    let selected: Bool
    let detailed: Bool
    let indent: CGFloat
    let onSelect: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        selected: Bool = false,
        detailed: Bool = false,
        indent: CGFloat = 0,
        onSelect: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.selected = selected
        self.detailed = detailed
        self.indent = indent
        self.onSelect = onSelect
        self.content = content
    }

    private var fixed: CGFloat? { style == .group ? (detailed ? 50 : 38) : nil }

    private var minimum: CGFloat {
        switch style {
            case .listHeader, .groupHeader: Style.Spacing.rowHeight
            case .list, .group: detailed ? Style.Spacing.rowDetailHeight : Style.Spacing.rowHeight
        }
    }

    private var header: Bool { style == .listHeader || style == .groupHeader }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        let row = HStack(alignment: .center, spacing: Style.Spacing.md) {
            // Tree rows always carry their indent spacer, so the spacing after it is a constant inset
            // at every depth rather than something that appears from the first level down.
            if style == .list { Color.clear.frame(width: indent) }
            content()
        }
        .environment(\.newRowHovered, hovered)
        .frame(maxWidth: .infinity, minHeight: fixed ?? minimum, maxHeight: fixed, alignment: .leading)
        .padding(.horizontal, style == .group ? Style.Spacing.md : header ? Style.Spacing.sm : .zero)
        .padding(.bottom, style == .listHeader ? 6 : .zero)
        .background(shape.fill(selected && !header ? Style.Tint.accent.opacity(0.3) : .clear))
        .contentShape(shape)
        .onHover { hovering in hovered = hovering }

        if let onSelect {
            Button(action: onSelect) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// Two views sharing one slot: the first at rest, the next while the row is hovered.
struct NewStack: View {
    @Environment(\.newRowHovered) private var hovered

    let resting: AnyView
    let active: AnyView

    var body: some View {
        // The resting view alone sets the size, so a stacked icon occupies exactly what the same icon
        // does unstacked; the active view overlays it without taking part in layout.
        resting
            .opacity(hovered ? .zero : Style.Opacity.full)
            .overlay {
                active.opacity(hovered ? Style.Opacity.full : .zero).allowsHitTesting(hovered)
            }
            .frame(height: Style.Spacing.rowHeight, alignment: .center)
    }
}

/// The disclosure on an expandable row. Ported from `ListLayout.hoverLeading`.
struct NewDisclosure: View {
    static let size: CGFloat = 15 * 1.25

    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.tertiary.opacity(0.3))
                    .frame(width: Self.size, height: Self.size)

                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .frame(width: Self.size, height: Self.size, alignment: .center)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .frame(width: Self.size, height: Self.size, alignment: .center)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Containers

struct NewList<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            header()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.newRowStyle, .list)
    }
}

/// Ported from `GroupLayout`: label above, rows in a filled container below.
struct NewGroup<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            header()
                .environment(\.newRowStyle, .groupHeader)

            VStack(spacing: .zero) { content() }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Style.Shape.medium.fill(Style.Background.group))
                .environment(\.newRowStyle, .group)
        }
        .padding(.vertical, Style.Spacing.md)
    }
}

/// Ported from `GroupDivider`.
struct NewDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, Style.Spacing.md)
            .opacity(0.4)
    }
}

/// Picks one reference out of a list — the compact counterpart to a picker, for choosing a
/// library object rather than a value.
struct NewLoadMenu: View {
    let label: String
    let references: [Reference]
    let onPick: (Reference) -> Void

    var body: some View {
        SwiftUI.Menu {
            ForEach(references, id: \.self) { reference in
                Button {
                    onPick(reference)
                } label: {
                    Text(reference.descriptor.name)
                    Iconography.icon(for: reference, size: Style.Dimension.icon)
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}


/// Ported from `ItemPicker`: a menu over a set of choices.
struct NewPicker: View {
    let options: [String]
    let selected: String
    let onChange: (String) -> Void

    var body: some View {
        SwiftUI.Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onChange(option)
                } label: {
                    Text(option)
                    if option == selected { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: Style.Spacing.md) {
                Text(selected)
                    .lineLimit(Style.Limit.singleLine)
                Spacer(minLength: .zero)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .font(.system(size: 12))
            .frame(width: 132, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

/// Ported from `ItemRangePicker`: a notched track for an ordered scale.
struct NewRangePicker: View {
    let options: [String]
    let selected: String
    let onChange: (String) -> Void

    private static let track: CGFloat = 84
    private static let height: CGFloat = 16
    private static let notch: CGFloat = 3

    private var index: Int {
        let found = options.firstIndex(of: selected) ?? 0
        return min(max(found, 0), max(options.count - 1, 0))
    }

    private var step: CGFloat {
        guard options.count > 1 else { return 0 }
        return (Self.track - Self.height) / CGFloat(options.count - 1)
    }

    var body: some View {
        HStack(spacing: Style.Spacing.md) {
            Text(options.indices.contains(index) ? options[index] : selected)
                .font(.system(size: 12))
                .foregroundStyle(Style.Foreground.subtle)
                .lineLimit(Style.Limit.singleLine)

            Spacer(minLength: .zero)

            ZStack(alignment: .leading) {
                Style.Shape.capsule.fill(Style.Background.control)

                ForEach(Array(options.indices), id: \.self) { notch in
                    Circle()
                        .fill(Style.Foreground.faint)
                        .frame(width: Self.notch, height: Self.notch)
                        .offset(x: Self.height / 2 + step * CGFloat(notch) - Self.notch / 2)
                }

                Circle()
                    .fill(Style.Foreground.primary)
                    .frame(width: Self.height, height: Self.height)
                    .offset(x: step * CGFloat(index))
            }
            .frame(width: Self.track, height: Self.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    guard step > 0 else { return }
                    let position = (drag.location.x - Self.height / 2) / step
                    let target = min(max(Int(position.rounded()), 0), options.count - 1)
                    guard target != index else { return }
                    onChange(options[target])
                }
            )
            .animation(.smooth(duration: 0.15), value: index)
        }
        .frame(width: 132, alignment: .trailing)
    }
}


/// Makes a row draggable when its reference is transferable. Eligibility is a runtime question,
/// so nothing about it is described in params.
struct NewDraggable: ViewModifier {
    let reference: Reference?

    func body(content: Self.Content) -> some View {
        guard let reference, ReferenceTransfer.canDrag(reference) else { return AnyView(content) }
        return AnyView(content.onDrag { ReferenceTransfer.provider(for: reference) ?? NSItemProvider() })
    }
}
