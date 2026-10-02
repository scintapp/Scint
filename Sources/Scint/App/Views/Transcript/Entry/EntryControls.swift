import SwiftUI
import ScintComponents


struct EntryControls<Content: View>: View {
    var created: Date
    var trailing: Bool = true
    var frame: CGFloat = 14
    @ViewBuilder var content: Content

    @State private var hovered = false

    var timestamp: some View {
        Text(created, style: .time)
            .font(Typography.footnote)
            .foregroundStyle(Style.Foreground.faint)
    }

    var buttons: some View {
        Image(systemName: "document.on.document")
            .font(.system(size: 11))
            .tint(Style.Foreground.faint)
            .foregroundStyle(Style.Foreground.faint, Style.Foreground.faint, Style.Foreground.faint)
    }

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading) {
            Color.clear.frame(height: frame)

            content
                .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)

            HStack(spacing: 8) {
                if trailing {
                    timestamp
                    buttons
                } else {
                    buttons
                    timestamp
                }
            }
            .frame(maxHeight: frame, alignment: .center)
            .padding(.horizontal, 8)
            .opacity(hovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .contentShape(Rectangle())
        .onHover { hovered in withAnimation(Style.Motion.disclosure) { self.hovered = hovered } }
    }
}
