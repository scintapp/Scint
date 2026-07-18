import AgencyRuntime
import SwiftUI


enum ComposerCanvasModel: CaseIterable {
    case composing
    var label: String { "Composer" }
    var image: String { "ellipses.bubble" }
}

@Observable final class ComposerCanvas: Panel {
    var model: ComposerCanvasModel = .composing
    var state: StateContainer = .init()

    func controls(_ model: any Model) -> Controls { EmptyMap.controls(model) }
    func parameters(_ model: any Model) -> Params { EmptyMap.parameters(model) }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state

        return HorizontalSplit(
            $state.presented,
            $state.position,
            leading: {
                ComposerComposeCanvas(panel: self, model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            trailing: {
                StudioCanvasEditor(panel: self, model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { EmptyView() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { EmptyView() }
        }
    }
}
