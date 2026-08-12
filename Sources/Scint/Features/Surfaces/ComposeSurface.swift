import SwiftUI


struct ComposeInput: View {
    let model: any Model

    var controls: some View {
        HStack(alignment: .center) {
            Spacer()
            Button { let _ = model.start(model.session.origin) } label: {
                Image(systemName: "arrow.up")
                    .frame(maxWidth: 25, maxHeight: 24)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let input = model.session.input {
                EditorComponent(input, minimumHeight: 32, maximumHeight: 256)
                    .id(input)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
//                    .glassEffect(.clear, in: Design.Shape.input)
//                    .glassEffect(.regular.tint(Design.Background.base.opacity(0.9)), in: Design.Shape.input)
                    .overlay(Design.Shape.input.strokeBorder(Design.Border.controlBorder, lineWidth: 0.5))
                controls
            }
        }
        .frame(maxWidth: 660)
    }
}

struct ComposeSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptEntries(model: model)
                .frame(maxWidth: 660, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            ComposeInput(model: model)
                .frame(maxWidth: 660, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
