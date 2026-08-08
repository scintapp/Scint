import SwiftUI


struct SpaceHeader: View {
    var model: any Model

    var origin: Reference { model.session.origin }

    var body: some View {
        Spacer().frame(height: 24)
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(origin.descriptor.name)
                    .font(.title.weight(.semibold))
                Text(origin.descriptor.description)
            }
            .frame(maxWidth: 440, alignment: .leading)

            VStack(alignment: .trailing, spacing: 12) {

            }
            .frame(maxWidth: 440, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpaceContent: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                let surface = AnySurface(panel: panel, model: model)
                surface.render(surface, SpaceGrid.parameters(model), SpaceGrid.controls(model))
            }
        }
        .frame(maxHeight: 144)
    }
}

struct SpaceSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }
    var active: Bool? { context?.state == .active }

    var body: some View {
        VStack {
            SpaceHeader(model: model)
            SpaceContent(panel: panel, model: model)

            VStack(alignment: .leading) {
                Text("Activity")
                    .font(.title2.weight(.medium))
                TranscriptSurface(panel: panel, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
