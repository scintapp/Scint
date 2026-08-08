import SwiftUI


struct Editor: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var editor = scint.editor

        NavigationSplitView {
            editor.sidebar.surface(editor)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            editor.content.surface(editor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $editor.inspector.state.presented) {
            editor.inspector.surface(editor)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}

@Observable final class EditorSidebar: Panel {
    var state: StateContainer = .init(presented: true)
    var surface: SidebarSurface = .workspace

    enum SidebarSurface: CaseIterable {
        case workspace, transcripts, library

        var label: String {
            switch self {
                case .workspace: "Workspace"
                case .transcripts: "Transcripts"
                case .library: "Library"
            }
        }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .transcripts: "bubble.left.and.text.bubble.right"
                case .library: "books.vertical"
            }
        }
    }

    func controls(_ model: any Model) -> Controls { FolderTree.controls(model) }
    func parameters(_ model: any Model) -> Params { FolderTree.parameters(model) }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state
        let surface = AnySurface(panel: self, model: model)

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
    var state: StateContainer = .init()

    func surface(_ model: any Model) -> some View {
        ScrollView {
            Color.clear.frame(height: 32)
            VStack {
                if let scene = model.session.scene {
                    EditorComponent(scene)
                        .id(scene)
                        .frame(maxWidth: 680, alignment: .topLeading)
                } else {
                    Text("Nothing Open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            Color.clear.frame(height: 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .bottom) { EditorBar(model: model) }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { PathControls(model: model) }
        }
    }
}

@Observable final class EditorInspector: Panel {
    var state: StateContainer = .init()
    enum InspectorSurface: String, CaseIterable { case scene, space, workspace }
    func controls(_ model: any Model) -> Controls { SceneGroup.controls(model) }
    func parameters(_ model: any Model) -> Params { SceneGroup.parameters(model)}

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
