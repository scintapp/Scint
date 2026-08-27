import SwiftUI


struct ComposeControls: View {
    let model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Spacer()

                Button { let _ = model.start(model.session.origin) } label: {
                    Image(systemName: "arrow.up")
                        .frame(maxWidth: 25, maxHeight: 24)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonBorderShape(.circle)
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
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
                .frame(alignment: .center)

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
                Style.Shape.large
                    .fill(Style.Background.group)
            }
            .background {
                Style.Shape.large
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
            ScrollView {
                VStack(spacing: 0) {
                    if let transcript = model.session.transcript {
                        TranscriptSection(transcript: transcript, model: model).id(transcript)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: 660, maxHeight: .infinity, alignment: .top)

                Color.clear.frame(height: 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollEdgeEffectStyle(.hard, for: .top)

            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

