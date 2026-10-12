import SwiftUI
import ScintComponents


struct EntryNotice: View {
    var content: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: Style.Border.width)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Style.Tint.alert.bright)
                Text(content)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(Typography.detail)
            .foregroundStyle(Style.Foreground.secondary)
            .layoutPriority(1)
            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: Style.Border.width)
        }
    }
}
