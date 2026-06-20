import AgencyRuntime
import SwiftUI


@Observable final class Content: Panel {
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

    func controls(_ agency: AgencyModel) -> Controls { SheetsMap.controls(agency, self) }
    func parameters(_ agency: AgencyModel) -> Parameters { SheetsMap.parameters(agency, self) }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            ContentHeader()
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
