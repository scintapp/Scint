import AgencyRuntime
import SwiftUI


@Observable final class InspectorOutline: Panel {
    var model: Model = .outline
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Model: String, CaseIterable {
        case outline, settings

        var label: String {
            switch self {
                case .outline: "InspectorOutline"
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
            InspectorOutlineTabs()
            switch self.model {
                case .outline: Builder.build(agency, self)
                case .settings: Builder.build(agency, self)
            }
        }
    }
}
