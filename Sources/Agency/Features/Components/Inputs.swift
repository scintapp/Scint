import AgencyRuntime
import SwiftUI


struct FilterInput: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

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
        .onAppear { isFocused = true }
    }
}

struct ComposerInput: View {
    @Environment(AgencyModel.self) private var agency
    var ref: Reference { agency.session.selected.space ?? agency.session.workspace }

    private var composable: Bool {
        (Space.with(ref, { $0.composable }) ?? Workspace.with(ref, { $0.composable }))!
    }

    private var input: Reference {
        let closure = (Space.with(ref, { $0.closure }) ?? Workspace.with(ref, { $0.closure }))!
        return Closure.with(closure, { $0.input })! ?? Sheet.new(ref, input: true)
    }

    private func send(_ input: Reference) {
        guard composable, agency.compose(ref, input: input) != nil else { return }
        _ = Sheet.new(ref, input: true)
    }

    var body: some View {
        let input = input

        ZStack(alignment: .bottom) {
            AgencyEditor(input)
                .id(input)
                .frame(minHeight: 24, maxHeight: 256, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background { Design.Shape.input.fill(Design.Background.block.opacity(0.38)) }
                .overlay {
                    Design.Shape.input
                        .strokeBorder(Color.primary.opacity(0.17), lineWidth: 0.5)
                }

            HStack {
                Spacer()
                Button { send(input) } label: {
                    Image(systemName: "arrow.up")
                        .frame(maxWidth: 24, maxHeight: 24)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                }
                .disabled(!composable)
                .opacity(composable ? 1 : 0.45)
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}
