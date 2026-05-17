import AgencyRuntime
import SwiftUI


struct SectionHeader: View {
    @State private var isHovered = false
    let name: String
    let onAdd: (() -> Void)?

    init(name: String, onAdd: (() -> Void)? = nil) {
        self.name = name
        self.onAdd = onAdd
    }

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .contentShape(RoundedRectangle(cornerRadius: 10.0))
        .onHover { isHovered = $0 }
    }
}

struct SectionLabel: View {
    let name: String
    let image: String
    var tint: Color = .secondary
    var detail: String?

    init(_ name: String, image: String, tint: Color = .secondary, detail: String? = nil) {
        self.name = name
        self.image = image
        self.tint = tint
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.82))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

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

struct SectionLink: View {
    @State private var isHovered = false
    let name: String
    let image: String
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let selected: Bool
    let onSelect: () -> Void

    init(name: String, image: String, tint: Color? = nil,
         trailingImage: String? = nil, count: Int? = nil, indent: CGFloat = 0,
         selected: Bool = false, onSelect: @escaping () -> Void) {

        self.name = name
        self.image = image
        self.trailingImage = trailingImage
        self.count = count
        self.indent = indent
        self.selected = selected
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: onSelect) {
            ItemRow(
                name: name, trailingImage: trailingImage, count: count,
                isHovered: isHovered, selected: selected) {

                    HStack {
                        if indent > 0 { Color.clear.frame(width: indent - 8) }
                        Image(systemName: image)
                            .font(.system(size: 14))
                            .frame(width: 18, height: 18, alignment: .center)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SectionAddItemRow: View {
    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var isActive = false
    let onCommit: (_ name: String) -> Void

    init(placeholder: String = "New Item", onCommit: @escaping (_ name: String) -> Void) {
        self.onCommit = onCommit
    }

    var body: some View {
        Button { isActive = true; isFocused = true } label: { }
            .buttonStyle(.plain)
    }
}

struct SectionDetailRow<Trailing: View>: View {
    let image: String
    let name: String
    @ViewBuilder var trailing: Trailing

    init(image: String, name: String, @ViewBuilder trailing: () -> Trailing) {
        self.image = image
        self.name = name
        self.trailing = trailing()
    }

    var body: some View {
        Image(systemName: image)
            .frame(width: 18, height: 18, alignment: .center)
            .foregroundStyle(.secondary)
        Text(name).font(.system(size: 12))
        Spacer()
        trailing
    }
}

struct SectionLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false
    let name: String
    let image: String
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let isExpanded: Bool
    let selected: Bool
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void

    init(
        name: String,
        image: String,
        trailingImage: String? = nil,
        count: Int? = nil,
        indent: CGFloat = 0,
        isExpanded: Bool = false,
        selected: Bool = false,
        onSelect: @escaping () -> Void,
        onToggleExpanded: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.image = image
        self.trailingImage = trailingImage
        self.count = count
        self.indent = indent
        self.isExpanded = isExpanded
        self.selected = selected
        self.onSelect = onSelect
        self.onToggleExpanded = onToggleExpanded
        self.content = content
    }

    var body: some View {
        Button(role: nil, action: onSelect) {
            ItemRow(name: name, trailingImage: trailingImage, count: count, indent: indent, isHovered: isHovered, selected: selected) {
                Button(role: nil, action: onToggleExpanded) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.tertiary.opacity(0.3))
                            .opacity(isHovered ? 1 : 0)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .opacity(isHovered ? 1 : 0)
                        Image(systemName: image)
                            .font(.system(size: 14))
                            .opacity(isHovered ? 0 : 1)
                    }
                    .frame(width: 18, height: 18, alignment: .center)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        if isExpanded { content() }
    }
}
