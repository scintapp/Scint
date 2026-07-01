import AgencyRuntime
import SwiftUI


@Observable final class DetailComposer: Panel {
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
        ZStack(alignment: .top) {
            VStack {
                Color.clear.frame(height: 60)
                ScrollView {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
    }
}
