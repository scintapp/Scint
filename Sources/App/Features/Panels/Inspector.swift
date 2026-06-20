import AgencyRuntime
import SwiftUI


@Observable final class Outline: Panel {
    var model: Model = .outline
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

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
                case .outline: "list.bullet.rectangle"
                case .settings: "gearshape"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch self.model {
            case .outline: OutlineMap.controls(agency, self)
            case .settings: SettingsMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch self.model {
            case .outline: OutlineMap.parameters(agency, self)
            case .settings: SettingsMap.parameters(agency, self)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            OutlineTabs()
            switch self.model {
                case .outline: Builder.build(agency, self)
                case .settings: Builder.build(agency, self)
            }
        }
    }
}

@Observable final class Inspector: Panel {
    var model: Model = .settings
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Model: String, CaseIterable {
        case settings, preview

        var label: String {
            switch self {
                case .settings: "Settings"
                case .preview: "Preview"
            }
        }

        var image: String {
            switch self {
                case .settings: "gearshape.2"
                case .preview: "eyeglasses"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .settings: return SettingsMap.controls(agency, self)
            case .preview: return PreviewMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .settings: return SettingsMap.parameters(agency, self)
            case .preview: return PreviewMap.parameters(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    self.presented.toggle()
                    NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "sidebar.squares.trailing")
                        .foregroundStyle(.primary.opacity(0.9))
                }
                .padding(.horizontal, 1)
                .labelsHidden()
            }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            InspectorTabs()
            Builder.build(agency, self)
        }
        .environment(agency)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}
