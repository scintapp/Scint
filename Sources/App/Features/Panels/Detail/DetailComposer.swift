import AgencyRuntime
import SwiftUI


@Observable final class DetailComposer: Panel {
    var model: Model = .composer
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case composer }

    func controls(_ agency: AgencyModel) -> Controls {
        WorkspaceMap.controls(agency, self)
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        WorkspaceMap.parameters(agency, self)
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .bottom) {
            if let transcript = agency.session.context?.transcript {
                TranscriptView(ref: transcript)
                Spacer()
            }

            ComposerInput()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(8)
    }
}
