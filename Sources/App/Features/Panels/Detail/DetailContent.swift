import AgencyRuntime
import SwiftUI


@Observable final class DetailContent: Panel {
    var model: Model = .sheets
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable {
        case sheets
        var label: String { "Sheets" }
        var image: String { "text.alignleft" }
    }

    func controls(_ agency: AgencyModel) -> Controls { ContentMap.controls(agency, self) }
    func parameters(_ agency: AgencyModel) -> PanelParams { ContentMap.parameters(agency, self) }

    func view(_ agency: AgencyModel) -> some View {
        var selected: Reference? { agency.session.selected.space }

        return ZStack(alignment: .top) {
            HStack(alignment: .center) {
                if let selected {
                    Text(selected.descriptor.name)
                        .frame(height: 50, alignment: .center)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .ignoresSafeArea(.all, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: 50, alignment: .leading)
            .padding(12)

            ScrollView {
                Color.clear.frame(height: 50)
                Builder.build(agency, self)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
