import AgencyRuntime
import SwiftUI


struct ComposerInputControls: View {
    @Environment(AgencyModel.self) private var agency

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            Button { agency.compose() } label: {
                Image(systemName: "arrow.up")
                    .frame(maxWidth: 25, maxHeight: 25)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 15, weight: .semibold))
            }
            .disabled(!agency.composable)
            .opacity(agency.composable ? 1 : 0.45)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

struct ComposerInput: View {
    @Environment(AgencyModel.self) private var agency

    var body: some View {
        ZStack(alignment: .bottom) {
            if let input = agency.input {
                EditorComponent(input, menuPlacement: .centerTop)
                    .id(input)
                    .frame(minHeight: 24, maxHeight: 256, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background { Design.Shape.input.fill(Design.Background.block) }
                    .overlay {
                        Design.Shape.input
                            .strokeBorder(Color.primary.opacity(0.17), lineWidth: 0.5)
                    }
            }

            ComposerInputControls()
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}
