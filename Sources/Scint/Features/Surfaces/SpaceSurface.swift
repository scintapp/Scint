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
        
    }
}



