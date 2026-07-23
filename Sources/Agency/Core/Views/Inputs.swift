import AgencyRuntime
import SwiftUI


struct ComposerInputControls: View {
    let model: any Model

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            Button { let _ = model.compose(model.session.origin) } label: {
                Image(systemName: "arrow.up")
                    .frame(maxWidth: 25, maxHeight: 24)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 15, weight: .semibold))
            }
            .disabled(!model.session.composable)
            .opacity(model.session.composable ? 1 : 0.45)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

struct ComposerInput: View {
    let model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            if let input = model.session.input {
                EditorComponent(input, minimumHeight: 32, maximumHeight: 256)
                    .id(input)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background { Design.Shape.input.fill(Design.Background.console) }
                    .overlay(Design.Shape.input.strokeBorder(Color.primary.opacity(0.17), lineWidth: 0.5))
            }
            ComposerInputControls(model: model)
        }
        .frame(maxWidth: 660)
    }
}
