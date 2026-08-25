import SwiftUI


struct ComposeControls: View {
    let model: any Model

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            Button { let _ = model.start(model.session.origin) } label: {
                Image(systemName: "arrow.up")
                    .frame(maxWidth: 25, maxHeight: 24)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonBorderShape(.circle)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

struct ComposeInput: View {
    let model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            if let input = model.session.input {
                EditorComponent(input, minimumHeight: 24, maximumHeight: 256)
                    .id(input)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(Style.Shape.input.stroke(Style.Border.card, lineWidth: 1))
                    .background(Style.Background.console)
                    .clipShape(Style.Shape.input)
                ComposeControls(model: model)
                    .opacity(0.0)
            }
        }
        .frame(maxWidth: 660)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

struct ComposeSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptSurface(panel: panel, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}


