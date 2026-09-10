import SwiftUI


struct MaterialBlock: View {
    let block: Material.Block
    var isSelected = false

    var body: some View {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref):
                ReferenceCard(ref: ref, isSelected: isSelected)
            case .text(_, let content):
                TextBlock(content: content)
                    .background(Style.Shape.medium.fill(isSelected ? Style.Background.control : .clear))
            case .task(_, let content, let completed):
                TaskBlock(content: content, completed: completed)
                    .background(Style.Shape.medium.fill(isSelected ? Style.Background.control : .clear))
        }
    }
}

struct TextBlock: View {
    let content: String

    var body: some View {
        Text(Attribute.text(content))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskBlock: View {
    let content: String
    let completed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.lg) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, Style.Spacing.xs)

            Text(content)
                .font(Typography.prose)
                .foregroundStyle(completed ? Style.Foreground.faint : Style.Foreground.base)
                .strikethrough(completed, color: Style.Foreground.faint)
                .lineSpacing(Style.Spacing.xs)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Style.Spacing.lg)
        .padding(.vertical, Style.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskCompletionIndicator: View {
    var completed: Bool

    var body: some View {
        Iconography.Icon(
            symbol: completed ? "checkmark.square.fill" : "square",
            tint: completed ? Style.Foreground.subtle : Style.Foreground.faint,
            sizing: Style.Dimension.iconLarge
        )
        .frame(width: Style.Dimension.iconLarge, height: Style.Dimension.iconLarge)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Blocks") {
    let blocks: [Material.Block] = [
        .text(UUID(), "A **formatted note** with *emphasis* and an `inline code` example."),
        .task(UUID(), "Collect the prospect URL and latest email thread before running the brief.", false),
        .task(UUID(), "Group questions by business goal, constraints, and decision process.", true),
        .task(UUID(), "Add a final section for risks that should not be waved away during the call.", false)
    ]

    return VStack(alignment: .leading, spacing: Style.Spacing.md) {
        ForEach(blocks) { block in
            MaterialBlock(block: block)
        }
    }
    .padding(Style.Spacing.xxl)
    .frame(width: Style.Spacing.contentMaxWidth)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}
#endif
