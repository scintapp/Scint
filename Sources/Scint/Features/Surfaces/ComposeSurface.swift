import SwiftUI


struct ComposeControls: View {
    let model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Button { let _ = model.start(model.session.origin) } label: {
                    Image(systemName: "arrow.up")
                        .frame(maxWidth: 25, maxHeight: 24)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonBorderShape(.circle)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ComposeInput: View {
    let model: any Model

    var body: some View {
        VStack {
            TranscriptPicker(model: model)
            ZStack(alignment: .top) {
                if let input = model.session.input {
                    EditorComponent(input, minHeight: 30, maxHeight: 256)
                        .id(input)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                ComposeControls(model: model)
                    .frame(alignment: .trailing)
                    .opacity(0)
            }
            .background { Style.Shape.medium.fill(Style.Background.group) }
            .background { Style.Shape.medium.stroke(Style.Border.base, lineWidth: 1, antialiased: true) }
            .frame(maxWidth: 680)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

struct ComposeSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ZStack(alignment: .top) {
            TranscriptSurface(panel: panel, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 12)
            ComposeInput(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 12)
        }
    }
}
