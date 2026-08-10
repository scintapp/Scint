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
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $studio.inspector.state.presented) {
            studio.inspector.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}

@Observable final class StudioSidebar: Frame {
    var state: AppState = .init(presented: true)

    func controls(_ model: any Model) -> Controls { SidebarMapper.controls(model) }
    func parameters(_ model: any Model) -> Params { SidebarMapper.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(host: self, model: model)
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

@Observable final class StudioContent: Frame {
    var state: AppState = .init()
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

@Observable final class StudioInspector: Frame {
    var state: AppState = .init()
    var surface: InspectorSurface = .workspace
    enum InspectorSurface: String, CaseIterable { case scene, space, workspace }
    func controls(_ model: any Model) -> Controls { SpaceGroup.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGroup.parameters(model) }

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

