import ScintComponents
import SwiftUI


struct ItemField: View {
    let value: String
    let onChange: (String) -> Void

    var body: some View {
        TextField("", text: Binding(get: { value }, set: { onChange($0) }))
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .frame(width: 112)
    }
}

struct Filter: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    var height: CGFloat = 28

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height, style: .circular)

        VStack {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .padding(.leading, 8)
                    .foregroundStyle(isFocused ? Style.Foreground.primary : Style.Foreground.secondary)
                    .font(.system(size: 13))

                TextField("Filter", text: $text)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
                    .foregroundStyle(isFocused ? Style.Foreground.primary : Style.Foreground.secondary)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
            .background(shape.fill(Style.Background.surface).stroke(Style.Border.hairline, lineWidth: 0.5))
            .contentShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: height)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
