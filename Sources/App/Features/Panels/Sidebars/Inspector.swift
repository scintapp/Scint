import AgencyRuntime
import SwiftUI


@Observable final class Inspector: Panel {
    var model: Model = .settings
    var context: Context = .inspector
    var layout: Layout = .group
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Context: String, CaseIterable { case composer, inspector }

    enum Model: String, CaseIterable {
        case outline, preview, settings

        var label: String {
            switch self {
                case .outline: "Outline"
                case .preview: "Preview"
                case .settings: "Settings"
            }
        }

        var image: String {
            switch self {
                case .outline: "list.bullet.rectangle"
                case .preview: "eyeglasses"
                case .settings: "gearshape.2"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        if context == .composer { return ComposerMap.controls(agency, self) }
        else {
            switch model {
                case .outline: return OutlineMap.controls(agency, self)
                case .preview: return PreviewMap.controls(agency, self)
                case .settings: return SettingsMap.controls(agency, self)
            }
        }
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        if context == .composer { return ComposerMap.parameters(agency, self) }
        else {
            switch model {
                case .outline: return OutlineMap.parameters(agency, self)
                case .preview: return PreviewMap.parameters(agency, self)
                case .settings: return SettingsMap.parameters(agency, self)
            }
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorPickerToggle() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            switch context {
                case .composer:
                    ZStack(alignment: .bottom) {
                        if let transcript = agency.session.context?.transcript {
                            TranscriptView(ref: transcript)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }

                        ComposerInput()
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .padding(8)
                            .zIndex(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .inspector:
                    InspectorTabs()
                    Builder.build(agency, self)
                    FilterInput()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { toolbar() }
    }
}
