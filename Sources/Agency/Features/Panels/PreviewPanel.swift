import SwiftUI
import AgencyRuntime


//struct PreviewToolbar: ToolbarContent {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some ToolbarContent {
//        @Bindable var preview = agency.studio.inspector
//        ToolbarSpacer(.flexible, placement: .automatic)
//        ToolbarItem(placement: .primaryAction) {
//            InspectorToggle(presented: $preview.presented)
//        }
//        .sharedBackgroundVisibility(preview.presented ? .hidden : .visible)
//    }
//}

@Observable final class Preview: Frame {
    var presented: Bool = true
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    func controls(_ agency: AgencyModel) -> Closures { PreviewMapper.closures(agency, self) }
    func params(_ agency: AgencyModel) -> Params { PreviewMapper.params(agency, self) }
}

