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
                        .foregroundStyle(Design.Foreground.secondary)
                        .lineLimit(5)
                } else {
                    Text(origin.descriptor.description)
                        .font(Typography.message)
                        .foregroundStyle(Design.Foreground.quaternary)
                        .lineLimit(5)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
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
                VStack(spacing: 0) {
                    SpaceHeader(model: model)
                        .frame(alignment: .top)

                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 0) {
                            TranscriptEntries(model: model)
                            Color.clear.frame(height: 64)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        ContextSurface(panel: panel, model: model)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.leading, 24)
                .padding(.trailing, ContextSurface.width + 44)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}



