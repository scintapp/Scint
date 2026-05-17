
import AgencyRuntime
import SwiftUI


struct ContentToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { NavigationControls() }
        ToolbarItem(placement: .principal) { RuntimeControls() }
        ToolbarItem(placement: .primaryAction) { LayoutPicker() }
        ToolbarItem(placement: .primaryAction) { DetailsToggle() }
        ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Pathfinder() }
    }
}

@Observable final class Content: Frame {
    var model: Modality = .browse
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Modality: String, CaseIterable {
        case browse, edit

        var image: String {
            switch self {
            case .browse: "app"
            case .edit: "square.and.pencil"
            }
        }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        @Bindable var content = agency.studio.content

        return HorizontalSplit($content.presented, position: $content.position) {
            switch content.model {
            case .edit:
                EditorPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

            case .browse:
                BrowserPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
            }
        } trailing: {
            DetailsPanel()
                .frame(maxWidth: 280, maxHeight: .infinity)
                .padding(.trailing, 8)
        }
        .background(Design.Background.content)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}




