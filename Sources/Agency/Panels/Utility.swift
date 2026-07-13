import AgencyRuntime
import SwiftUI


@Observable final class Utility: Panel {
    var model: Model = .processes
    var position: CGFloat = 0
    var presented: Bool = false
    var state = SurfaceState()

    enum Model: CaseIterable { case processes }

    func view(_ agency: AgencyModel) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Spacer()
                UtilityToggle()
            }
            .frame(height: 30)
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
            Processes()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Design.Background.console)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
