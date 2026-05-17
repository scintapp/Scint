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

    func controls(_ model: AgencyModel) -> Controls { PreviewMapper.controls(model) }
    func params(_ model: AgencyModel) -> Params { PreviewMapper.params(model) }
}

