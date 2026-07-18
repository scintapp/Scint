import AgencyRuntime
import SwiftUI


enum CanvasModel: CaseIterable {
    case browsing, composing, editing

    var label: String {
        switch self {
            case .browsing: "Browser"
            case .composing: "Composer"
            case .editing: "Editor"
        }
    }

    var image: String {
        switch self {
            case .browsing: "rectangle.stack"
            case .composing: "ellipses.bubble"
            case .editing: "doc.plaintext"
        }
    }
}

@Observable final class Canvas: Panel {
    var model: CanvasModel = .browsing
    var state: StateContainer = .init()
    var browsing: Bool { model == .browsing }
    var editing: Bool { model == .editing }

    func controls(_ model: any Model) -> Controls {
        if browsing { BrowserMap.controls(model) }
        else { EmptyMap.controls(model) }
    }

    func parameters(_ model: any Model) -> Params {
        if browsing { BrowserMap.parameters(model) }
        else { EmptyMap.parameters(model) }
    }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state

        return HorizontalSplit(
            $state.presented,
            $state.position,
            leading: {
                StudioCanvasBrowser(panel: self, model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            trailing: {
                if editing {
                    StudioCanvasEditor(panel: self, model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationControls(model: model, canvas: self) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls(canvas: self) }
        }
    }
}
