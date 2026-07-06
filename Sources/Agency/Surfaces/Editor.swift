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
        ZStack(alignment: .top) {
            ScrollView {
                Group {
                    if let sheet = agency.session.active {
                        AgencyEditor(sheet)
                            .id(sheet)
                            .frame(maxWidth: 710, alignment: .topLeading)
                    } else {
                        Text("Nothing Open")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Design.Foreground.primary)
                        Text("")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Design.Foreground.secondary)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)
            }
        }
    }
}
