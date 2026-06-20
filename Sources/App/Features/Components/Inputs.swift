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
            .background(.primary.opacity(0.1))
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: 26)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

struct ComposerInput: View {
    @Environment(AgencyModel.self) var agency
    var space: Reference { agency.session.selected.space ?? agency.session.workspace }
    var input: Reference {
        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []
        return state.first { $0.type is Sheet.Type } ?? space
    }

    private var canSend: Bool {
        let text = Sheet.with(input, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? ""
        return !text.isEmpty
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        ZStack(alignment: .bottom) {
            Editor(input)
                .id(input)
                .frame(minHeight: 120, maxHeight: 360, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            HStack {
                Spacer()
                Button { agency.compose(space) } label: {
                    Image(systemName: "arrow.up")
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 2)
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: 26, alignment: .bottom)
            .padding(.trailing, 8)
            .padding(.bottom, 10)

        }
        .background(shape.fill(.primary.opacity(0.02)))
        .overlay(shape.stroke(.primary.opacity(0.17), lineWidth: 0.75))
    }
}
