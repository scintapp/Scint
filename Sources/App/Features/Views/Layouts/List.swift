import AgencyRuntime
import SwiftUI


struct ListLabel: View {
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
                .frame(width: 25, height: 25)
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

struct ListLink: View {
    @State private var isHovered = false
    private let iconSize: CGFloat = 18
    let ref: Reference?
    let name: String
    let image: String
    let tint: Color?
    let trailingImage: String?
    let count: Int?
    let leadingAccessory: AnyView?
    let accessory: AnyView?
    let indent: CGFloat
    let selected: Bool
    let onSelect: () -> Void

    init(name: String, ref: Reference? = nil, image: String, tint: Color? = nil,
         trailingImage: String? = nil, count: Int? = nil, leadingAccessory: AnyView? = nil,
         accessory: AnyView? = nil, indent: CGFloat = 0,
         selected: Bool = false, onSelect: @escaping () -> Void) {

        self.name = name
        self.ref = ref
        self.image = image
        self.tint = tint
        self.trailingImage = trailingImage
        self.count = count
        self.leadingAccessory = leadingAccessory
        self.accessory = accessory
        self.indent = indent
        self.selected = selected
        self.onSelect = onSelect
    }

    @ViewBuilder private var icon: some View {
        if let ref { Iconography.icon(for: ref, size: iconSize) }
        else if let tint { Iconography.Icon(symbol: image, tint: tint, size: iconSize) }
        else {
            Image(systemName: image)
                .font(.system(size: iconSize * 0.8, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
        }
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
        .frame(width: iconSize, height: iconSize)
    }

    var body: some View {
        Button(action: onSelect) {
            ListRow(
                name: name, accessory: accessory, trailingImage: trailingImage, count: count,
                isHovered: isHovered, selected: selected) {
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
    let accessory: AnyView?
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let isHovered: Bool
    let selected: Bool
    let isEditing: Bool
    let editText: Binding<String>?
    let onCommitEdit: (() -> Void)?
    let content: Content

    init(
        name: String, accessory: AnyView? = nil, trailingImage: String? = nil, count: Int? = nil,
        indent: CGFloat = 0, isHovered: Bool = false, selected: Bool = false, isEditing: Bool = false,
        editText: Binding<String>? = nil, onCommitEdit: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Content) {
            self.name = name
            self.accessory = accessory
            self.count = count
            self.indent = indent
            self.isHovered = isHovered
            self.selected = selected
            self.isEditing = isEditing
            self.editText = editText
            self.onCommitEdit = onCommitEdit
            self.trailingImage = trailingImage
            self.content = leading()
        }

    var body: some View {
        HStack {
            Color.clear.frame(width: indent)
            content

            if isEditing, let editText {
                TextField("Name", text: editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onSubmit { onCommitEdit?() }
            } else {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
        .frame(maxWidth: .infinity, minHeight: 26)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.secondary.opacity(0.1) : .clear))
        .foregroundStyle(.primary)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ListHeader: View {
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

struct ListLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false
    private let iconSize: CGFloat = 18
    let ref: Reference?
    let name: String
    let image: String
    let tint: Color?
    let trailingImage: String?
    let count: Int?
    let leadingAccessory: AnyView?
    let accessory: AnyView?
    let indent: CGFloat
    let isExpanded: Bool
    let selected: Bool
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void

    init(
        name: String,
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
        onSelect: @escaping () -> Void,
        onToggleExpanded: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.ref = ref
        self.image = image
        self.tint = tint
        self.trailingImage = trailingImage
        self.count = count
        self.leadingAccessory = leadingAccessory
        self.accessory = accessory
        self.indent = indent
        self.isExpanded = isExpanded
        self.selected = selected
        self.onSelect = onSelect
        self.onToggleExpanded = onToggleExpanded
        self.content = content
    }

    @ViewBuilder private var icon: some View {
        if let ref { Iconography.icon(for: ref, size: iconSize) }
        else if let tint { Iconography.Icon(symbol: image, tint: tint, size: iconSize) }
        else {
            Image(systemName: image)
                .font(.system(size: iconSize * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
        }
    }

    @ViewBuilder private var hoverLeading: some View {
        if let leadingAccessory {
            leadingAccessory
        } else {
            Button(role: nil, action: onToggleExpanded) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.tertiary.opacity(0.3))
                        .frame(width: 18, height: 18, alignment: .center)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: 18, height: 18, alignment: .center)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        Button(role: nil, action: onSelect) {
            ListRow(name: name, accessory: accessory, trailingImage: trailingImage, count: count, indent: indent, isHovered: isHovered, selected: selected) {
                ZStack {
                    hoverLeading
                        .opacity(isHovered ? 1 : 0)
                        .allowsHitTesting(isHovered)

                    icon
                        .opacity(isHovered ? 0 : 1)
                }
                .frame(width: iconSize, height: iconSize)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        if isExpanded { content() }
    }
}
