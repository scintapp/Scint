import AgencyRuntime
import SwiftUI


@Observable final class ComposerDetail: Panel {
    var model: Model = .composer
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case composer }

    func controls(_ agency: AgencyModel) -> Controls {
        ComposerMap.controls(agency, self)
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        ComposerMap.parameters(agency, self)
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            VStack {
                Color.clear.frame(height: 60)
                ScrollView {
                    Group {
                        if let transcript = Runtime.shared.context(for: agency.session.workspace)?.transcript { TranscriptView(ref: transcript) }
                        else { EmptyState(ref: agency.session.workspace) }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(.all, edges: .top)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .zIndex(0)

                ComposerInput()
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .zIndex(1)
            }
            .frame(maxWidth: 710, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
    }
}

@Observable final class BrowserDetail: Panel {
    var model: Model = .space
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case space, workspace }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .space: return BrowserMap.controls(agency, self)
            case .workspace: return WorkspaceMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .space: return BrowserMap.parameters(agency, self)
            case .workspace: return WorkspaceMap.parameters(agency, self)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        ScrollView { Builder.build(agency, self) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .top)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { agency.focus(nil) }
            }
    }
}

@Observable final class EditorDetail: Panel {
    var model: Model = .detail
    var layout: Layout = .content
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case detail }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarItem(placement: .primaryAction) { InspectorToggle() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            DetailHeader()
            GeometryReader { geometry in
                ScrollView {
                    Color.clear.frame(height: 50)
                    if let sheet = agency.session.opened.sheet {
                        Editor(sheet, minimumCanvasHeight: max(120, geometry.size.height - 98))
                            .id(sheet)
                            .frame(maxWidth: 710, alignment: .topLeading)
                            .padding(24)
                    } else {
                        EmptyState(ref: agency.session.workspace)
                            .frame(maxWidth: 710, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar { toolbar() }
    }
}

@Observable final class Detail: Panel {
    var model: Model = .browser
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case browser, composer, editor }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .browser: return BrowserMap.controls(agency, self)
            case .composer: return ComposerMap.controls(agency, self)
            case .editor: return .init()
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .browser: return BrowserMap.parameters(agency, self)
            case .composer: return ComposerMap.parameters(agency, self)
            case .editor: return .init()
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarItem(placement: .primaryAction) { ModalityPicker() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Breadcrumbs() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console
        return ZStack(alignment: .top) {
            VerticalSplit($console.presented, position: $console.position) {
                ScrollView {
                    Color.clear.frame(height: 50)
                    switch model {
                        case .browser: agency.studio.browser.view(agency)
                        case .composer: agency.studio.composer.view(agency)
                        case .editor: agency.studio.editor.view(agency)
                    }
                }
            } bottom: {
                agency.studio.console.view(agency)
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .title)
        .toolbar { toolbar() }
    }
}
