import AgencyRuntime
import SwiftUI


struct EmptyState: View {
    private func capability(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Tint.artifact)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Design.Foreground.caption)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .center) {
                Text("Nothing Open")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Design.Foreground.primary)
                Text("")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
