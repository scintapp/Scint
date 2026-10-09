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
            .frame(minWidth: 0, maxWidth: 480, alignment: .trailing)
    }
}
