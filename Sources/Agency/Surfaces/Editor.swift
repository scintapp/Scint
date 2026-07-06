import AgencyRuntime
import SwiftUI


@Observable final class Editor: Panel {
    var model: Model = .detail
    var layout: Layout = .grid
    var position: CGFloat = 0
    var presented: Bool = true
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case detail }

    func view(_ agency: AgencyModel) -> some View {
        Group {
            if let sheet = agency.session.active {
                AgencyEditor(sheet)
                    .id(sheet)
                    .frame(maxWidth: 710, alignment: .topLeading)
            } else {
                EmptyState()
                    .frame(maxWidth: 710, alignment: .topLeading)
            }
        }
    }
}
