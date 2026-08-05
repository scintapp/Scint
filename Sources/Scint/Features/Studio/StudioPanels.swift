import SwiftUI


@Observable final class StudioSidebar: Panel {
    var state: StateContainer = .init()
    var surface: SidebarSurface = .workspace

    enum SidebarSurface: CaseIterable {
        case workspace, library, transcripts

        var label: String {
            switch self {
                case .workspace: "Workspace"
                case .library: "Library"
                case .transcripts: "Transcripts"
            }
        }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .library: "books.vertical"
                case .transcripts: "bubble.left.and.text.bubble.right"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch self.surface {
            case .workspace: return WorkspaceSidebar.controls(model)
            case .library: return LibrarySidebar.controls(model)
            case .transcripts: return TranscriptsSidebar.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch self.surface {
            case .workspace: return WorkspaceSidebar.parameters(model)
            case .library: return LibrarySidebar.parameters(model)
            case .transcripts: return TranscriptsSidebar.parameters(model)
        }
    }

    func panel(_ model: any Model) -> some View {
        Group {
            @Bindable var state = self.state
            AnySurface(panel: self, model: model)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .safeAreaBar(edge: .bottom) { Filter(text: $state.filter) }
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { SidebarToggle(presented: $state.presented) }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                }
        }
    }
}

@Observable final class StudioCanvas: Panel {
    var state: StateContainer = .init()
    var mode: CanvasMode = .leading
    var leading: CanvasSurface = .space
    var trailing: CanvasSurface = .composer

    enum CanvasMode: CaseIterable { case leading, trailing, both }
    enum CanvasSurface: CaseIterable { case composer, editor, space, none }

    func controls(_ model: any Model) -> Controls {
        switch self.leading {
            case .composer: return .init()
            case .editor: return .init()
            case .space: return SpaceCanvas.controls(model)
            case .none: return .init()
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch self.leading {
            case .composer: return .init()
            case .editor: return .init()
            case .space: return SpaceCanvas.parameters(model)
            case .none: return .init()
        }
    }

    func panel(_ model: any Model) -> some View {
        Group {
            @Bindable var state = self.state

            HSplit($state.presented, $state.position) {
                ScrollView {
                    Color.clear.frame(height: 24)
                    TranscriptSurface(panel: self, model: model)
                }
            } trailing: {
                ScrollView {
                    Color.clear.frame(height: 24)
                    AnySurface(panel: self, model: model)
                }
            }
        }
        .ignoresSafeArea(.all, edges: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) {
            HStack(alignment: .center) {
                NavigationControls(model: model, canvas: self)
                Divider().padding(.vertical, 8)
                PathBar(model: model).frame(maxWidth: .infinity)
                PaletteBar(model: model).frame(maxWidth: 128)
            }
            .frame(maxHeight: 30)
            .padding(.leading, 8)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { StudioControls() }.sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls(canvas: self) }
        }
    }
}

@Observable final class StudioConsole: Panel {
    var state: StateContainer = .init()
    var surface: ConsoleSurface = .processes

    enum ConsoleSurface: CaseIterable { case processes }

    func controls(_ model: any Model) -> Controls { .init() }

    func parameters(_ model: any Model) -> Params { .init() }

    func panel(_ model: any Model) -> some View {
        ZStack(alignment: .top) {
            ConsoleBar()
            AnySurface(panel: self, model: model)
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

@Observable final class StudioInspector: Panel {
    var state: StateContainer = .init()
    var surface: InspectorSurface = .workspace

    enum InspectorSurface: String, CaseIterable { case sheet, space, workspace }

    func controls(_ model: any Model) -> Controls {
        switch self.surface {
            case .sheet: return SheetInspector.controls(model)
            case .space: return SpaceInspector.controls(model)
            case .workspace: return SpaceInspector.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch self.surface {
            case .sheet: return SheetInspector.parameters(model)
            case .space: return SpaceInspector.parameters(model)
            case .workspace: return SpaceInspector.parameters(model)
        }
    }

    func panel(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                @Bindable var state = self.state
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}
