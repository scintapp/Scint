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

    // `groupHeight` is what separates the two kinds of row that share this view. A group row states
    // one, and takes the settings dressing: a tall leading box, inset edges, full-size controls. A
    // list row, a menu row and a panel row state none, size themselves, and are left bare — they
    // bring their own metrics and the dressing would swallow them.
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

    private var harness: Reference? {
        Space.with(ref, { $0.harness }).flatMap { $0 }
    }

    var body: some View {
        let harness = harness
        let intent = harness.flatMap { Harness.with($0, { $0.intent }) }
        let explanation = harness?.descriptor.description ?? ""

        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            HStack(alignment: .center, spacing: Style.Spacing.label) {
                Iconography.icon(for: harness ?? ref, size: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(harness?.descriptor.name ?? "No harness")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)

                    Text(intent?.rawValue.capitalized ?? "Unassigned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Style.Foreground.secondary)
                        .lineLimit(1)
                }
            }

            GroupDivider()

            Text(explanation.isEmpty
                 ? "Add a harness to make this space runnable."
                 : explanation)
                .font(.system(size: 12))
                .foregroundStyle(explanation.isEmpty ? Style.Foreground.secondary : Style.Foreground.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Style.Spacing.inset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Style.Shape.card.fill(Style.Background.surface))
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
                .background(Style.Shape.card.fill(Style.Background.surface))

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
