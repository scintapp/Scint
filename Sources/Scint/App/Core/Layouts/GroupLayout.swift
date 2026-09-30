import SwiftUI
import ScintRuntime
import ScintComponents


enum GroupMetrics {
    static let row: CGFloat = 44
    static let detailRow: CGFloat = 48
    static let headerTop: CGFloat = 8

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

struct GroupRow<Leading: View, Trailing: View>: View {
    let title: Text
    let detail: Text?
    let detailLineLimit: Int
    let spacing: CGFloat?
    let spacerMinLength: CGFloat?
    let groupHeight: CGFloat?
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        title: Text,
        detail: Text? = nil,
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
            title: Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.88)),
            detail: description.isEmpty ? nil : Text(description)
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
    let ref: Reference

    enum Field { case name, description }

    @State private var name: String?
    @State private var description: String?
    @FocusState private var focused: Field?

    private var harness: Reference? {
        Space.with(ref, { $0.harness }).flatMap { $0 }
    }

    var body: some View {
        let harness = harness
        let intent = harness.flatMap { Harness.with($0, { $0.intent }) }

        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            HStack(alignment: .center) {
                Iconography.icon(for: harness ?? ref, size: 18)
                    .frame(width: 20, height: 20, alignment: .center)
                    .padding(.trailing, 4)

                VStack(alignment: .leading) {
                    TextField("Name", text: .init(get: { name ?? ref.descriptor.name }, set: { name = $0 }))
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)
                        .focused($focused, equals: .name)
                        .onSubmit {
                            if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                Catalog.shared.update(ref) { $0.name = name }
                            }
                            name = nil
                        }

                    Text(intent?.rawValue.capitalized ?? "Unassigned")
                        .font(.system(size: 12))
                        .foregroundStyle(Iconography.accent(for: harness ?? ref))
                        .opacity(0.7)
                        .lineLimit(1)
                }
                .frame(alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 6)

            GroupDivider()

            TextField(
                "Description",
                text: .init(get: { description ?? ref.descriptor.description }, set: { description = $0 }),
                prompt: Text("Add a description...").foregroundStyle(Style.Foreground.subtle),
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Style.Shape.card.fill(Style.Background.group))
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

struct GroupLayout<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(title: String, footer: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack {
            Text(title)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.75))

            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .top)
                .background(Style.Shape.card.fill(Style.Background.group))

            if let footer {
                Text(footer)
                    .padding(.leading, 4)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
