import AgencyRuntime
import SwiftUI


@Observable final class StudioCanvas: Panel {
    var surface: CanvasSurface = .composing
    var state: StateContainer = .init()

    enum CanvasSurface: CaseIterable { case composing, editing }

    func panel(_ model: any Model) -> some View {
        @Bindable var state = self.state
        return HSplitView {
            SpaceContent(panel: self, model: model)
            TranscriptSurface(panel: self, model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) {
            HStack(alignment: .center) {
                NavigationControls(model: model, canvas: self)
                Divider().padding(.vertical, 8)
                PathBar(model: model).frame(maxWidth: .infinity)
                ActionsBar(model: model).frame(maxWidth: 128)
            }
            .frame(maxHeight: 30)
            .padding(.leading, 8)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { StudioControls() }
                .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls(canvas: self) }
        }
    }
}
