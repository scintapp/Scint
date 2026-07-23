import AgencyRuntime
import SwiftUI


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
                    .foregroundStyle(.secondary.opacity(0.9))
                    .font(.system(size: 13))

                TextField("Filter", text: $text)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
            .glassEffect(.regular, in: shape)
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: height)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
