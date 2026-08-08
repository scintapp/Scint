import SwiftUI


struct ScintStudio: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var studio = scint.studio

        NavigationSplitView {
            studio.sidebar.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            studio.content.surface(studio)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $studio.inspector.state.presented) {
            studio.inspector.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}

@Observable final class StudioSidebar: Panel {
    var state: StateContainer = .init(presented: true)

    func controls(_ model: any Model) -> Controls { SidebarMapper.controls(model) }
    func parameters(_ model: any Model) -> Params { SidebarMapper.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    @Bindable var state = self.state
                    SidebarToggle(presented: $state.presented)
                }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}

@Observable final class StudioContent: Panel {
    var state: StateContainer = .init()

    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
                ToolbarItem(placement: .navigation) { WorkspaceControls(model: model) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .principal) { ContextControls(model: model) }
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { PathMenuButton(model: model) }
            }
    }
}

@Observable final class StudioInspector: Panel {
    var state: StateContainer = .init()
    var surface: InspectorSurface = .workspace

    enum InspectorSurface: String, CaseIterable { case scene, space, workspace }

    func controls(_ model: any Model) -> Controls { SpaceGroup.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGroup.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                @Bindable var state = self.state
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}

