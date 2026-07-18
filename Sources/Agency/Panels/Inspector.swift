import SwiftUI


enum InspectorModel: String, CaseIterable {
    case space, sheet

    var label: String {
        switch self {
            case .space: "Space Inspector"
            case .sheet: "Sheet Inspector"
        }
    }

    var image: String {
        switch self {
            case .space: "app"
            case .sheet: "text.alignleft"
        }
    }

    @MainActor var icon: Iconography.Icon {
        switch self {
            case .space: Iconography.model(.space)
            case .sheet: Iconography.model(.sheet(.sheet))
        }
    }
}

@Observable final class Inspector: Panel {
    var model: InspectorModel = .space
    var state: StateContainer = .init()

    func controls(_ model: any Model) -> Controls {
        switch self.model {
            case .space: SpaceInspector.controls(model)
            case .sheet: SheetInspector.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch self.model {
            case .space: SpaceInspector.parameters(model)
            case .sheet: SheetInspector.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state
        let surface = AnySurface(panel: self, model: model)

        return surface.render(surface, parameters(model), controls(model))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { InspectorTabs(inspector: self) }
            .toolbar {
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}

