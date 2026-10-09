import SwiftUI
import ScintComponents


struct InputEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content, hugs: true)
            .opacity(0.78)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Style.Shape.message.fill(Style.Background.message))
            .overlay(Style.Shape.message.strokeBorder(Style.Border.message, lineWidth: 0.5))
            .frame(minWidth: 0, maxWidth: 480, alignment: .trailing)
            .shadow(color: .black.opacity(0.5), radius: 0.33, y: 0.33)
    }
}
