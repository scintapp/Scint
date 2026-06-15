import AgencyRuntime
import Foundation
import SwiftUI


@Observable final class Console: Panel {
    var model: Model = .processes
    var layout: Layout = .table
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case processes }

    func controls(_ agency: AgencyModel) -> Controls {
        ProcessesMap.controls(agency, self)
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        ProcessesMap.parameters(agency, self)
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = self

        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                ProcessesOverview()
                Spacer()
                ConsoleToggle()
            }
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .background(Design.Background.console)
            .padding(.horizontal, 16)
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

            Builder.build(agency, self)
                .padding(.horizontal, 12)
        }
        .background(Design.Background.console)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
