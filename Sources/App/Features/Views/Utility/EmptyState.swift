import AgencyRuntime
import SwiftUI


struct EmptyState: View {
    let ref: Reference

    private func capability(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Tint.artifact)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Capabilities overview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 13) {
                capability(
                    icon: "rectangle.3.offgrid",
                    title: "Work with this space",
                    detail: "Use loaded sheets, files, commands, and context from \(ref.descriptor.name)."
                )
                capability(
                    icon: "text.badge.checkmark",
                    title: "Draft structured responses",
                    detail: "Prompts can include editor blocks, links, resources, and inline components."
                )
                capability(
                    icon: "wrench.and.screwdriver",
                    title: "Use connected tooling",
                    detail: "Commands and harnesses stay explicit, while the Composer reads the boundary context."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
