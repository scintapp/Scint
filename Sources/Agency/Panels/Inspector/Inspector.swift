import AgencyRuntime
import SwiftUI


@Observable final class Inspector: Panel {
    var model: Model = .composition
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Model: String, CaseIterable {
        case composition, preview

        var label: String {
            switch self {
            case .composition: "Settings"
            case .preview: "Preview"

            }
        }

        var image: String {
            switch self {
            case .preview: "eyeglasses"
            case .composition: "gearshape.2"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
        case .composition: return CompositionMap.controls(agency, self)
        case .preview: return PreviewMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
        case .composition: return CompositionMap.parameters(agency, self)
        case .preview: return PreviewMap.parameters(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        @Bindable var panel = self
        
        return Group {
            ToolbarSpacer(.flexible, placement: .automatic)
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
            InspectorTabs(inspector: self)
            Builder.build(agency, self)
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}
