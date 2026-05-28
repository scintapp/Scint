import AgencyRuntime
import SwiftUI


struct ContentToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { NavigationControls().environment(agency) }
        ToolbarSpacer(.flexible, placement: .navigation)
        ToolbarItem(placement: .principal) { ProcessControls().environment(agency) }
        ToolbarSpacer(.flexible, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) { LayoutPicker().environment(agency) }
        ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Pathfinder().environment(agency) }
    }
}

@Observable final class Content: Panel {
    var model: Model = .space
    var layout: Layout = .grid
    var position: CGFloat = 400
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case sheet, space, workspace }

    func closures(_ agency: AgencyModel) -> Closures {
        switch self.model {
        case .sheet: .init()
        case .space:
            agency.session.space == nil ? RootSpaceMap.closures(agency, self) : SpaceMap.closures(agency, self)
        case .workspace: RootSpaceMap.closures(agency, self)
        }
    }

    func params(_ agency: AgencyModel) -> Params {
        switch self.model {
        case .sheet: .init()
        case .space:
            switch self.layout {
            case .grid: SpaceMap.params(agency, self)
            case .table: SpaceMap.params(agency, self)
            default: SpaceMap.params(agency, self)
            }
        case .workspace:
            switch self.layout {
            case .grid: RootSpaceMap.params(agency, self)
            case .table: RootSpaceMap.params(agency, self)
            default: RootSpaceMap.params(agency, self)
            }
        }
    }

//    @MainActor func build(_ agency: AgencyModel) -> some View {
//        @Bindable var console = agency.studio.console
//        @Bindable var content = self
//        let closures = closures(agency)
//        let params = params(agency)
//    
//        return HSplitView {
//            GeometryReader { proxy in
//                ScrollView {
//                    Color.clear.frame(height: 80)
//                    if let _ = agency.session.space {
//                        Builder.build(self, closures, params)
//                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 90, 0), alignment: .topLeading)
//                    } else {
//                        Builder.build(self, closures, params)
//                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 90, 0), alignment: .topLeading)
//                    }
//                }
//            }
//            ScrollView {
//                Color.clear.frame(height: 80)
//                if let ref = agency.session.sheet {
//                    Editor(ref: ref)
//                        .padding(.top, 20)
//                        .frame(maxWidth: 720, maxHeight: .infinity, alignment: .top)
//                }
//            }
//        }
//        .environment(agency)
//        .ignoresSafeArea(.container, edges: .top)
//        .scrollEdgeEffectStyle(.soft, for: .top)
//        .toolbar(removing: .title)
//        .toolbar { ContentToolbar() }
//    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console
        @Bindable var content = self
        let closures = closures(agency)
        let params = params(agency)

        return VerticalSplit($console.presented, position: $console.position) {
            GeometryReader { proxy in
                ScrollView {
                    Color.clear.frame(height: 80)
                    switch self.model {
                    case .sheet:
                        if let ref = agency.session.sheet {
                            Editor(ref: ref)
                                .padding(.top, 20)
                                .frame(maxWidth: 720, maxHeight: .infinity)
                        }
        
                    case .space:
                        Builder.build(self, closures, params)
                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 90, 0), alignment: .topLeading)
        
                    case .workspace:
                        Builder.build(self, closures, params)
                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 90, 0), alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Design.Background.base)
            }
        } bottom: {
            agency.studio.console.build(agency)
        }
        .environment(agency)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar(removing: .title)
        .toolbar { ContentToolbar() }
    }
}
