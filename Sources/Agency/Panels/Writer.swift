import AgencyRuntime
import SwiftUI


@Observable final class Writer: Panel {
    var model: Model = .writer
    var layout: Layout = .content
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case writer }

    func view(_ agency: AgencyModel) -> some View {
        ScrollView {
            Color.clear.frame(height: 90)
            if let sheet = agency.session.opened.sheet {
                Editor(sheet)
                    .id(sheet)
                    .frame(maxWidth: 710, alignment: .topLeading)
                    .padding(24)
            } else {
                EmptyState(ref: agency.session.workspace)
                    .frame(maxWidth: 710, alignment: .topLeading)
            }
        }
        .environment(agency)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
