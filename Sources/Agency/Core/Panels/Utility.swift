import AgencyRuntime
import SwiftUI


@Observable final class Utility: Panel {
    var model: Model = .processes
    var layout: Layout = .table
    var position: CGFloat = 0
    var presented: Bool = false
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case processes }

    func toolbar() -> some View {
        HStack(alignment: .center) {
            Spacer()
            UtilityToggle()
        }
        .frame(height: 30, alignment: .bottomLeading)
        .background(Design.Background.console)
        .overlay(alignment: .top) {
            Group {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 0.5)
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 1)
            }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            toolbar()
            Processes()
        }
    }
}
