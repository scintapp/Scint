import SwiftUI


@Observable final class ContentPanel: Panel {
    var state: PanelState = .init()
    var content: Content = .workspace
    enum Content: CaseIterable { case space, workspace, editor }
    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }

    func surface(_ model: any Model) -> some View {
        Group {
            if model.session.origin.type == Workspace.self { WorkspaceSurface(panel: self, model: model) }
            else { SpaceSurface(panel: self, model: model) }
        }
    }
}

//@Observable final class ContentPanel: Panel {
//    var state: PanelState = .init()
//    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
//    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }
//
//    func surface(_ model: any Model) -> some View {
//        Group {
//            @Bindable var state = self.state
//            HSplit($state.presented, $state.position) {
//                if model.session.origin.type == Workspace.self { WorkspaceSurface(panel: self, model: model) }
//                else { SpaceSurface(panel: self, model: model) }
//            } trailing: {
//                if let material = model.session.material {
//                    EditSurface(panel: self, model: model)
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
