import SwiftUI
import ScintRuntime
import ScintComponents


enum GroupMetrics {
    static let row: CGFloat = 44
    static let detailRow: CGFloat = 48
    static let headerTop: CGFloat = 8
    static let tile: CGFloat = 36

    static func height(for description: String) -> CGFloat {
        description.isEmpty ? row : detailRow
    }
}

struct GroupDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 8)
            .opacity(0.4)
    }
}

struct GroupTile<Label: View>: View {
    let image: String
    let ref: Reference?
    let disclosure: Bool
    @ViewBuilder let label: Label

    init(image: String, ref: Reference? = nil, disclosure: Bool = false, @ViewBuilder label: () -> Label) {
        self.image = image
        self.ref = ref
        self.disclosure = disclosure
        self.label = label()
    }

    init(_ item: ItemParams, disclosure: Bool) where Label == SwiftUI.Text? {
        let text = item.description.isEmpty ? item.name : item.description
        self.init(image: item.image, ref: item.ref, disclosure: disclosure) {
            if !text.isEmpty { SwiftUI.Text(text).foregroundStyle(item.description.isEmpty ? Style.Foreground.secondary : Style.Foreground.primary) }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if let ref { Iconography.icon(for: ref).frame(width: 18, height: 18) }
            else if !image.isEmpty { Image(systemName: image).foregroundStyle(Style.Foreground.secondary) }

            label.lineLimit(1)

            Spacer(minLength: 0)

            if disclosure {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Style.Foreground.secondary)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: GroupMetrics.tile, alignment: .leading)
        .background(Style.Shape.group.fill(Style.Background.group))
        .contentShape(Style.Shape.group)
    }
}

struct GroupMoment: View {
    let item: ItemParams
    let elements: NSDatePicker.ElementFlags
    let onChange: (String) -> Void

    @State private var editing = false

    var body: some View {
        GroupRow(label: editing ? "" : item.description.isEmpty ? item.name : item.description) {
            Image(systemName: item.image)
                .frame(width: 18, height: 18, alignment: .center)
        } trailing: {
            if editing {
                DateField(
                    date: Value.formatter.date(from: item.value ?? "") ?? .now,
                    elements: elements,
                    onChange: { onChange(Value.formatter.string(from: $0)) },
                    onEnd: { editing = false }
                )
                .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = true }
    }
}

struct GroupNote: View {
    let placeholder: String
    let onSubmit: (String) -> Void

    @State private var text = ""

    var body: some View {
        SwiftUI.TextField("Note", text: $text, prompt: SwiftUI.Text(placeholder).foregroundStyle(Style.Foreground.subtle), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .lineLimit(4...12)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .onSubmit {
                let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !note.isEmpty else { return }
                onSubmit(note)
                text = ""
            }
    }
}

struct GroupCheck: View {
    let item: ItemParams
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onToggle) { TaskCompletionIndicator(completed: item.active, size: 14) }
                .buttonStyle(.plain)

            SwiftUI.Text(item.name)
                .font(.system(size: 13))
                .foregroundStyle(item.active ? Style.Foreground.secondary : Style.Foreground.primary)
                .strikethrough(item.active, color: Style.Foreground.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct GroupOutline: View {
    let item: ItemParams
    let depth: Int
    let expanded: (AnyHashable) -> Bool
    let selected: (ItemParams) -> Bool
    let onExpand: (AnyHashable) -> Void
    let onSelect: (ItemParams) -> Void

    var body: some View {
        let open = expanded(item.id)

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                Button { onExpand(item.id) } label: {
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Style.Foreground.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .opacity(item.isParent ? 1 : 0)
                .disabled(!item.isParent)

                MarkdownText(content: item.name, font: .systemFont(ofSize: 13))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected(item) ? Style.Tint.accent.bright.opacity(0.5) : .clear))
            .contentShape(Rectangle())
            .onTapGesture { onSelect(item) }

            if item.isParent, open {
                ForEach(item.items) { child in
                    GroupOutline(item: child, depth: depth + 1, expanded: expanded, selected: selected, onExpand: onExpand, onSelect: onSelect)
                }
            }
        }
    }
}

struct GroupMeter: View {
    let item: ItemParams

    var segments: [ItemParams] { item.items.flatMap(\.items).filter { ($0.count ?? 0) > 0 } }
    var total: Int { segments.compactMap(\.count).reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.image)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Style.Foreground.secondary)
                    .frame(width: 18, height: 18)
                    .padding(.trailing, 12)

                SwiftUI.Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.88))

                Spacer()

                if let value = item.value { SwiftUI.Text(value).font(.system(size: 13)).monospacedDigit() }
            }
            .frame(height: 18)

            GeometryReader { geometry in
                let width = geometry.size.width - CGFloat(max(segments.count - 1, 0))

                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.tint ?? Style.Foreground.secondary)
                            .frame(width: max(width * CGFloat(segment.count ?? 0) / CGFloat(max(total, 1)), 2))
                    }
                }
            }
            .frame(height: 12)
            .background(Style.Background.selection)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack(alignment: .top) {
                ForEach(item.items) { legend in
                    HStack(alignment: .top, spacing: 10) {
                        HStack(spacing: 3) {
                            ForEach(legend.items) { segment in
                                Circle()
                                    .fill(segment.tint ?? Style.Foreground.secondary)
                                    .frame(width: 9, height: 9)
                            }
                        }
                        .frame(height: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            SwiftUI.Text(legend.name)
                                .font(.system(size: 13))
                                .foregroundStyle(Style.Foreground.secondary)

                            if let value = legend.value {
                                SwiftUI.Text(value)
                                    .font(.system(size: 13))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct GroupRow<Leading: View, Trailing: View>: View {
    let title: SwiftUI.Text
    let detail: SwiftUI.Text?
    let detailLineLimit: Int
    let spacing: CGFloat?
    let spacerMinLength: CGFloat?
    let groupHeight: CGFloat?
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        title: SwiftUI.Text,
        detail: SwiftUI.Text? = nil,
        detailLineLimit: Int = 1,
        spacing: CGFloat? = nil,
        spacerMinLength: CGFloat? = nil,
        groupHeight: CGFloat? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.detailLineLimit = detailLineLimit
        self.spacing = spacing
        self.spacerMinLength = spacerMinLength
        self.groupHeight = groupHeight
        self.leading = leading()
        self.trailing = trailing()
    }

    init(
        label: String,
        description: String = "",
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: SwiftUI.Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.88)),
            detail: description.isEmpty ? nil : SwiftUI.Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.72)),
            groupHeight: description.isEmpty ? 44 : 48,
            leading: leading,
            trailing: trailing
        )
    }

    private var dressed: Bool { groupHeight != nil }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if dressed {
                leading
                    .frame(height: 44, alignment: .center)
                    .foregroundStyle(Style.Foreground.secondary)
                    .font(.system(size: 16, weight: .light))
                    .padding(.leading, 6)
                    .padding(.trailing, 4)
            } else {
                leading
            }

            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                title.lineLimit(1)
                if let detail { detail.lineLimit(detailLineLimit) }
            }
            .frame(height: groupHeight, alignment: .center)

            Spacer(minLength: spacerMinLength)

            if dressed {
                trailing
                    .foregroundStyle(Style.Foreground.secondary)
                    .frame(height: groupHeight)
                    .labelsHidden()
                    .controlSize(.regular)
                    .padding(.trailing, 6)
            } else {
                trailing
            }
        }
        .frame(height: groupHeight, alignment: .center)
        .padding(.horizontal, dressed ? 8 : 0)
    }
}

struct GroupHeader: View {
    @State private var name: String?
    @State private var description: String?
    @FocusState private var focused: Field?
    let ref: Reference
    var subtitle = ""
    var described = true
    var active: AnyHashable?
    var onSelect: (SectionParams) -> Void = { _ in }

    enum Field { case name, description }

    private var interface: Reference? { Space.with(ref, { $0.interface }).flatMap { $0 } }
    private var intent: Intent? {
        guard let interface else { return nil }
        let values = Space.with(ref, { $0.input }).flatMap { Document.with($0, { $0.values(interface) }) }
        let intent: Intent? = if case .property(.string(let raw))? = values?["intent"] { Intent(rawValue: raw) } else { ref.context?.intent }
        return intent == Intent.none ? nil : intent
    }

    private var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    private var heading: (id: UUID, level: Int, text: String)? {
        Document.with(ref, { document in
            if case .heading(let id, let level, let text)? = document.blocks.first { (id, level, text) } else { nil }
        }) ?? nil
    }

    private var icon: Iconography.Icon {
        if let done = Document.with(ref, { TaskHeader.task($0)?.done }) ?? nil {
            return Iconography.Icon(symbol: done ? "checkmark.app" : "app", tint: Style.Tint.task.bright, sizing: 18)
        }
        guard let intent
        else { return Iconography.icon(for: ref, size: 18) }
        return Iconography.icon(for: intent, size: 18)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            HStack(alignment: .center) {
                icon
                    .frame(width: 20, height: 20, alignment: .center)
                    .padding(.trailing, 4)

                VStack(alignment: .leading) {
                    SwiftUI.TextField("Name", text: .init(get: { name ?? heading?.text ?? ref.descriptor.name }, set: { name = $0 }))
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)
                        .focused($focused, equals: .name)
                        .onSubmit {
                            if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                if let heading { Document.update(ref) { $0.update(.heading(heading.id, heading.level, name), at: 0) } }
                                else { Catalog.shared.update(ref) { $0.name = name } }
                            }
                            name = nil
                        }

                    SwiftUI.Text(subtitle.isEmpty ? intent?.rawValue.capitalized ?? updated : subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(intent == nil ? Style.Foreground.subtle : icon.tint)
                        .opacity(0.7)
                        .lineLimit(1)
                }
                .frame(alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 6)

            if described {
                GroupDivider()

                SwiftUI.TextField(
                    "Description",
                    text: .init(get: { description ?? ref.descriptor.description }, set: { description = $0 }),
                    prompt: SwiftUI.Text("Add a description...").foregroundStyle(Style.Foreground.subtle),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Style.Foreground.secondary)
                .focused($focused, equals: .description)
                .onSubmit {
                    if let description { Catalog.shared.update(ref) { $0.description = description } }
                    description = nil
                }
                .padding(.top, 2)
                .padding(.bottom, 8)
                .padding(.horizontal, 6)
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Style.Shape.group.fill(Style.Background.group))
        .onChange(of: focused) { _, field in
            if field != .name { name = nil }
            if field != .description { description = nil }
        }
        .onChange(of: ref) {
            name = nil
            description = nil
        }
    }
}

struct GroupGrid<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            if !title.isEmpty {
                SwiftUI.Text(title)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.75))
            }

            HStack(spacing: 8) { content() }
        }
    }
}

struct GroupLayout<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    let title: String
    let footer: String?
    let expanded: Bool
    let onToggle: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(title: String, footer: String?, expanded: Bool = true, onToggle: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.expanded = expanded
        self.onToggle = onToggle
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SwiftUI.Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.75))

                if onToggle != nil {
                    Spacer()

                    Disclosure(expanded: expanded)
                        .padding(.trailing, 4)
                        .opacity(hovered ? 1 : 0)
                }
            }
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if let onToggle { withAnimation(reduceMotion ? nil : .snappy(duration: 0.25), onToggle) } }
            .onHover { hovered = $0 }

            VStack {
                if expanded {
                    VStack(spacing: 0) { content() }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .background(Style.Shape.group.fill(Style.Background.group))
                        .transition(.disclosure)

                    if let footer {
                        SwiftUI.Text(footer)
                            .padding(.leading, 4)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(.secondary.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.disclosure)
                    }
                }
            }
            .padding(.top, expanded ? 8 : 0)
            .clipped()
        }
    }
}
