import AgencyRuntime
import SwiftUI


@Observable final class DetailEditor: Panel {
    var model: Model = .detail
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case detail }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                if let sheet = agency.session.active {
                    Editor(sheet)
                        .id(sheet)
                        .frame(maxWidth: 710, alignment: .topLeading)
                } else {
                    EmptyState(ref: agency.session.workspace)
                        .frame(maxWidth: 710, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
