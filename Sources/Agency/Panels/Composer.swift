import SwiftUI
import AgencyRuntime


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

@Observable final class Composer: Panel {
    var model: Model = .composer
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case composer }

    func controls(_ agency: AgencyModel) -> Controls {
        ComposerMap.controls(agency, self)
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        ComposerMap.parameters(agency, self)
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                ScrollView {
                    Color.clear.frame(height: 90)
                    Group {
                        if let transcript = Runtime.shared.context(for: agency.session.workspace)?.transcript { TranscriptView(ref: transcript) }
                        else { EmptyState(ref: agency.session.workspace) }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(.all, edges: .top)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .zIndex(0)

                ComposerInput()
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .zIndex(1)
            }
            .frame(maxWidth: 710, maxHeight: .infinity)
        }
        .environment(agency)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
