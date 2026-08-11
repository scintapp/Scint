import SwiftUI


//@Observable final class ContentPanel: Panel {
//    var state: PanelState = .init()
//    var content: Content = .workspace
//    enum Content: CaseIterable { case space, workspace, editor }
//    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
//    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }
//
//    func surface(_ model: any Model) -> some View {
//        Group {
//            switch content {
//                case .editor: Editor()
//                case .space: SpaceSurface(host: self, model: model)
//                case .workspace: WorkspaceSurface(host: self, model: model)
//            }
//        }
//        .safeAreaBar(edge: .top) {
//            HStack(alignment: .center) {
//                PathBar(model: model)
//                Spacer()
//                BadgesBar(model: model)
//            }
//            .frame(maxHeight: 30)
//        }
//        .toolbar {
//            ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
//            ToolbarSpacer(.flexible, placement: .primaryAction)
//            ToolbarItem(placement: .principal) { ContextControls(model: model) }
//            ToolbarSpacer(.flexible, placement: .primaryAction)
//            ToolbarItem(placement: .primaryAction) { ContextToggle() }
//        }
//    }
//}

@Observable final class ContentPanel: Panel {
    var state: PanelState = .init()
    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }

    func surface(_ model: any Model) -> some View {
        Group {
            if model.session.origin.type == Workspace.self { WorkspaceSurface(host: self, model: model) }
            else { SpaceSurface(host: self, model: model) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top) {
            HStack(alignment: .center) {
                PathBar(model: model)
                Spacer()
                BadgesBar(model: model)
            }
            .frame(maxHeight: 30)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { ContextToggle() }
        }
    }
}
