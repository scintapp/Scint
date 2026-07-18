import AgencyRuntime
import SwiftUI


enum CanvasModel: CaseIterable {
    case browsing, composing, editing

    var label: String {
        switch self {
            case .browsing: "CanvasBrowse"
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

    func controls(_ agency: AgencyModel) -> Controls {
        if browsing { BrowserMap.controls(agency) }
        else { EmptyMap.controls(agency) }
    }

    func parameters(_ agency: AgencyModel) -> Params {
        if browsing { BrowserMap.parameters(agency) }
        else { EmptyMap.parameters(agency) }
    }

    func surface(_ agency: AgencyModel) -> some View {
        @Bindable var state = self.state

        return HorizontalSplit(
            $state.presented,
            $state.position,
            leading: {
                CanvasBrowse(panel: self)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            trailing: {
                if editing {
                    CanvasEdit(panel: self)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
        .environment(agency)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls() }
        }
    }
}
