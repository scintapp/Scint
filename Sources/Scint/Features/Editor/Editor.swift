import SwiftUI


struct Editor: View {
    @Environment(ScintModel.self) var scint
    var body: some View { scint.editor.content.surface(scint.editor) }
}

@Observable final class EditorSidebar: Frame {
    var state: AppState = .init(presented: true)

    func controls(_ model: any Model) -> Controls { FolderTree.controls(model) }
    func parameters(_ model: any Model) -> Params { FolderTree.parameters(model) }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state
        let surface = AnySurface(host: self, model: model)
        return surface.render(surface, parameters(model), controls(model))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .bottom) { Filter(text: $state.filter) }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { SidebarToggle(presented: $state.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}

@Observable final class EditorContent: Panel {
    var state: AppState = .init()

    func surface(_ model: any Model) -> some View {
        EditorSurface(host: self, model: model)
            .safeAreaBar(edge: .bottom) { EditorBar(model: model) }
            .toolbar {
                ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { PathControls(model: model) }
            }
    }
}

@Observable final class EditorInspector: Panel {
    var state: AppState = .init()
    enum InspectorSurface: String, CaseIterable { case scene, space, workspace }
    func controls(_ model: any Model) -> Controls { SceneGroup.controls(model) }
    func parameters(_ model: any Model) -> Params { SceneGroup.parameters(model)}

    func surface(_ model: any Model) -> some View {
        AnySurface(host: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                @Bindable var state = self.state
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}
