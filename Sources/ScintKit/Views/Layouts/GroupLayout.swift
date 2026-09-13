import SwiftUI


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
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary.opacity(0.88)),
            detail: description.isEmpty ? nil : Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.72)),
            groupHeight: description.isEmpty ? 38 : 50,
            leading: leading,
            trailing: trailing
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if let groupHeight {
                leading
                    .frame(width: 38, height: groupHeight)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 15, weight: .medium))
            } else {
                leading
            }

            VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                title.lineLimit(1)
                if let detail { detail.lineLimit(detailLineLimit) }
            }
            .frame(height: groupHeight, alignment: .center)

            Spacer(minLength: spacerMinLength)

            if let groupHeight {
                trailing
                    .frame(height: groupHeight)
                    .labelsHidden()
                    .controlSize(.small)
            } else {
                trailing
            }
        }
        .frame(height: groupHeight, alignment: .center)
        .padding(.horizontal, groupHeight == nil ? 0 : 8)
    }
}

struct GroupHeader: View {
    let ref: Reference

    var body: some View {
        let name = ref.descriptor.name
        let description = ref.descriptor.description

        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Iconography
                    .icon(for: ref, size: 16)
                    .frame(alignment: .leading)
                    .padding(.top, 10)
                    .padding(.trailing, 4)

                Text(name)
                    .frame(alignment: .leading)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(.top, 10)
            }

            VStack(alignment: .center) {
                Text(description.isEmpty ? "Add a description..." : description)
                    .frame(alignment: .leading)
                    .foregroundStyle(
                        description.isEmpty ? Style.Foreground.faint : Style.Foreground.subtle
                    )
                    .font(.system(size: 12))
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Style.Shape.medium.fill(Style.Background.group))

            if let footer {
                Text(footer)
                    .padding(.leading, 4)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }
}
