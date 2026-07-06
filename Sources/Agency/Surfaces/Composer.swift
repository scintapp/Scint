import AgencyRuntime
import SwiftUI


struct ComposerInput: View {
    @Environment(AgencyModel.self) var agency
    @State private var input: Reference?
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    var space: Reference { agency.session.selected.space ?? agency.session.workspace }

    private var canSend: Bool {
        guard let input else { return false }
        let text = Sheet.with(input, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? ""
        return !text.isEmpty
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
                    .glassEffect(.regular.tint(Design.Background.base.opacity(0.4)), in: shape)
            }

            HStack {
                Spacer()
                Button { agency.compose(space) } label: {
                    Image(systemName: "arrow.up")
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                }
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

@Observable class Composer: Panel {
    let model: Model = .dispatch
    let layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case dispatch, execute, observe, traverse }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .bottom) {
            ComposerInput()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
