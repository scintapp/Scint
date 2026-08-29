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
            ZStack(alignment: .bottom) {
                if let input = model.session.input {
                    EditorComponent(input, minimumHeight: 30, maximumHeight: 256, menuPlacement: .caret)
                        .id(input)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                guard let transcript = model.session.transcript else { return }
                                model.select(transcript)
                            }
                        )
                    ComposeControls(model: model)
                }
            }
            .background {
                Style.Shape.small
                    .fill(Style.Background.group)
            }
            .background {
                Style.Shape.small
                    .stroke(Style.Border.base, lineWidth: 1, antialiased: true)
            }
            .frame(maxWidth: 660)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

struct ComposeSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptSurface(panel: panel, model: model)
                .frame(maxWidth: 660, maxHeight: .infinity, alignment: .top)
                .scrollEdgeEffectStyle(.hard, for: .top)

            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

