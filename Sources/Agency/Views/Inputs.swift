import AgencyRuntime
import SwiftUI


struct FilterInput: View {
    @State var text: String = ""
    @FocusState var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .circular)

        VStack {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .padding(.leading, 8)
                    .foregroundStyle(.secondary.opacity(0.9))
                    .font(.system(size: 13))

                TextField("Filter", text: $text)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, maxHeight: 26, alignment: .leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: 26, alignment: .leading)
            .glassEffect(.regular, in: shape)
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: 26)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

struct ComposerInput: View {
    @Environment(AgencyModel.self) var agency
    @State private var input: Reference?
    let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)
    var space: Reference { agency.session.selected.space ?? agency.session.workspace }

    private var canSend: Bool {
        guard let input else { return false }
        let text = Sheet.with(input, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? ""
        return !text.isEmpty
    }

    private func send() {
        guard let input, canSend else { return }
        _ = agency.compose(space, input: input)
        self.input = Sheet.new("Input", owner: space)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let input {
                AgencyEditor(input)
                    .id(input)
                    .frame(minHeight: 34, maxHeight: 240, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Design.Background.block.opacity(0.38))
                    .clipShape(shape)
                    .overlay {
                        shape
                            .strokeBorder(Color.primary.opacity(0.17), lineWidth: 0.5)
                    }

            }

            HStack {
                Spacer()
                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .frame(width: 26, height: 25)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .padding(.horizontal, 2)
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: 25, alignment: .bottom)
            .padding(.trailing, 8)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .onAppear { input = Sheet.new("Input", owner: space) }
        .onChange(of: space) { _, space in input = Sheet.new("Input", owner: space) }
    }
}
