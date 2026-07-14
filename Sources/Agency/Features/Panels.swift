import SwiftUI


@Observable final class Actions: Panel {
    @ObservationIgnored var query = ""
    var model: Model = .commands
    var queryRevision = 0
    var index: Int = 0
    var presented: Bool = false
    var state: SurfaceState = .init()

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { label }

        var label: String {
            switch self {
                case .commands: "Commands"
                case .interfaces: "Interfaces"
                case .library: "Library"
                case .workspace: "Workspace"
            }
        }

        var image: String {
            switch self {
                case .commands: "command"
                case .interfaces: "switch.2"
                case .library: "building.columns"
                case .workspace: "cube.transparent"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    func parameters(_ agency: AgencyModel) -> Params {
        switch model {
            case .commands: SearchMap.parameters(agency)
            case .interfaces: InterfacesMap.parameters(agency)
            case .library: ComponentsMap.parameters(agency)
            case .workspace: StructuresMap.parameters(agency)
        }
    }

    func setQuery(_ value: String) {
        guard query != value else { return }
        query = value
        queryRevision += 1
        index = 0
    }

    func reset() {
        query = ""
        queryRevision += 1
        index = 0
    }

    func cycleModel() {
        let modes = Model.allCases
        guard let current = modes.firstIndex(of: model) else { return }
        model = modes[(current + 1) % modes.count]
    }

    func view(_ agency: AgencyModel) -> some View { ActionsLayout() }
}

@Observable final class Canvas: Panel {
    var model: Model = .browser
    var presented: Bool = true
    var position: CGFloat = 480
    var state: SurfaceState = .init()

    enum Model: CaseIterable {
        case browser, composer, editor

        var label: String {
            switch self {
                case .browser: "Browser"
                case .composer: "Composer"
                case .editor: "Editor"
            }
        }

        var image: String {
            switch self {
                case .browser: "rectangle.stack"
                case .composer: "ellipses.bubble"
                case .editor: "doc.plaintext"
            }
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var canvas = self
        return HorizontalSplit($canvas.presented, $canvas.position) {
            agency.studio.features.composer
                .scrollEdgeEffectStyle(.hard, for: .top)
                .safeAreaBar(edge: .top, alignment: .leading) { PathBar() }
        } trailing: {
            Group {
                switch model {
                    case .browser: agency.studio.features.browser
                    case .editor: agency.studio.features.editor
                    default: agency.studio.features.browser
                }
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
            .safeAreaBar(edge: .top, alignment: .trailing) { ActionsBar() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar { toolbar () }
    }
}

@Observable final class Console: Panel {
    var model: Model = .processes
    var presented: Bool = false
    var state: SurfaceState = .init()

    enum Model: CaseIterable { case processes }

    func view(_ agency: AgencyModel) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Spacer()
                UtilityToggle()
            }
            .frame(height: 30)
            .overlay(alignment: .top) {
                Group {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 0.5)
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 1)
                }
            }
            Processes()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Design.Background.console)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@Observable final class Inspector: Panel {
    var model: Model = .settings
    var presented: Bool = false
    var state: SurfaceState = .init()

    enum Model: String, CaseIterable {
        case outline, settings

        var label: String {
            switch self {
                case .outline: "Outline"
                case .settings: "Settings"
            }
        }

        var image: String {
            switch self {
                case .outline: "text.alignleft"
                case .settings: "app"
            }
        }

        @MainActor var icon: Iconography.Icon {
            switch self {
                case .outline: Iconography.model(.sheet(.sheet))
                case .settings: Iconography.model(.space)
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .outline: SheetOutlineMap.controls(agency)
            case .settings: SpaceSettingsMap.controls(agency)
        }
    }

    func parameters(_ agency: AgencyModel) -> Params {
        switch model {
            case .outline: SheetOutlineMap.parameters(agency)
            case .settings: SpaceSettingsMap.parameters(agency)
        }
    }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorToggle() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        Builder.build(self, parameters(agency), controls(agency))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .sidebarToggle)
            .toolbar { toolbar() }
            .safeAreaBar(edge: .top) { InspectorTabs() }
    }
}

@Observable final class Navigator: Panel {
    var model: Model = .workspace
    var presented: Bool = true
    var state: SurfaceState = .init()

    enum Model: CaseIterable {
        case workspace, directories, transcripts, library

        var label: String {
            switch self {
                case .workspace: "Workspace"
                case .directories: "Files"
                case .transcripts: "Transcripts"
                case .library: "Library"
            }
        }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .directories: "folder"
                case .transcripts: "bubble.left.and.text.bubble.right"
                case .library: "books.vertical"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch self.model {
            case .library: LibraryMap.controls(agency)
            case .workspace: NavigatorMap.controls(agency)
            case .directories: DirectoryMap.controls(agency)
            case .transcripts: EmptyMap.controls(agency)
        }
    }

    func parameters(_ agency: AgencyModel) -> Params {
        switch self.model {
            case .library: LibraryMap.parameters(agency)
            case .workspace: NavigatorMap.parameters(agency)
            case .directories: DirectoryMap.parameters(agency)
            case .transcripts: EmptyMap.parameters(agency)
        }
    }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .primaryAction) { NavigatorToggle() }
            ToolbarSpacer(.fixed, placement: .primaryAction)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        Builder.build(self, parameters(agency), controls(agency))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .sidebarToggle)
            .toolbar { toolbar() }
            .safeAreaBar(edge: .top) { NavigatorTabs() }
    }
}
