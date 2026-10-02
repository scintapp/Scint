import SwiftUI
import ScintComponents


struct InputEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content, hugs: true)
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Style.Shape.message.fill(Style.Background.bubble))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(minWidth: 0, alignment: .trailing)
    }
}
