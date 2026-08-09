import SwiftUI


struct SpaceHeader: View {
    var model: any Model
    var origin: Reference { model.session.origin }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.blockSpacing) {
            VStack(alignment: .leading) {
                Text(origin.descriptor.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Design.Foreground.primary)
                    .padding(.bottom, 6)

                if origin.descriptor.description.isEmpty {
                    Text("Write a description...")
                        .font(Typography.message)
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(5)
                } else {
                    Text(origin.descriptor.description)
                        .font(Typography.message)
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(5)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                SpaceBadges(model: model)
                    .frame(alignment: .trailing)
            }
            .frame(alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
}

struct SpaceContent: Surface {
    var ref: Reference? = nil
    var panel: any Panel
    var model: any Model

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                let surface = AnySurface(panel: panel, model: model)
                let parameters = if let ref { SpaceGrid.content(ref) } else { panel.parameters(model) }
                surface.render(surface, parameters, panel.controls(model))
                    .scrollDisabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 144)
    }
}

struct SpaceSurface: Surface {
    var panel: any Panel
    var model: any Model
    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }
    var active: Bool? { context?.state == .active }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack {
                    SpaceHeader(model: model)
                        .frame(alignment: .top)
                    TranscriptEntries(model: model)
                        .frame(alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 12)


            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
