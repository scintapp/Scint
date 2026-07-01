import AgencyRuntime
import SwiftUI


@Observable final class DetailEditor: Panel {
    var model: Model = .detail
    var layout: Layout = .content
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case detail }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                ScrollView {
                    Color.clear.frame(height: 50)
                    if let sheet = agency.session.opened.sheet {
                        Editor(sheet, minimumCanvasHeight: max(120, geometry.size.height - 98))
                            .id(sheet)
                            .frame(maxWidth: 710, alignment: .topLeading)
                            .padding(24)
                    } else {
                        EmptyState(ref: agency.session.workspace)
                            .frame(maxWidth: 710, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
