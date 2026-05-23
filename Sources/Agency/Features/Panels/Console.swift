import AgencyRuntime
import Foundation
import SwiftUI


struct ConsoleToolbar: View {
    @Binding var presented: Bool

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            ConsoleToggle()
        }
        .padding(.bottom, -8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
        .background(Design.Background.console)
        .overlay(alignment: .top) {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 0.5)
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 1)
            }
        }
    }
}

@Observable final class Console: Panel {
    var model: Model = .processes
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case processes }

    func closures(_ agency: AgencyModel) -> Closures { .init() }

    func params(_ agency: AgencyModel) -> Params { .init() }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        @Bindable var console = self

        return VStack {
            ConsoleToolbar(presented: $console.presented)
                .background(Design.Background.console)

            Activities()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Design.Background.console)
        }
    }
}
