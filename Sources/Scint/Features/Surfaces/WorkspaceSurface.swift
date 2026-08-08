import SwiftUI


struct SpacePreviewCard: Surface {
    var model: any Model
    var panel: any Panel

    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }
    var active: Bool? { context?.state == .active }

    var body: some View {
        SpaceContent(panel: panel, model: model)
    }
}

struct WorkspaceSurface: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        ScrollView {
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}

#Preview("Workspace Surface") {

}

