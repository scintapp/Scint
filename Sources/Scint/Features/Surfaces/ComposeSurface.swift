import SwiftUI


struct ComposeControls: View {
    let model: any Model
    var input: Reference

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Button {
                    Material.update(input, { $0.clear() })
                    model.start(model.session.origin)
                } label: {
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

struct ComposeSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var material: Reference? { model.session.opened.material }

    var input: Reference {
        if origin.type == Space.self { return Space.with(origin, { $0.input })! }
        else { return Workspace.with(origin, { $0.input })! }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptSurface(panel: panel, model: model)
                .frame(maxHeight: .infinity, alignment: .top)
            VStack {
                TranscriptPicker(model: model)

                ZStack(alignment: .top) {
                    EditorComponent(input, minHeight: 64, maxHeight: 256)
                        .id(input)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    ComposeControls(model: model, input: input)
                        .id(input)
                        .frame(alignment: .trailing)
                        .opacity(0)
                }
                .background { Style.Shape.medium.fill(Style.Background.raised) }
                .overlay { Style.Shape.medium.stroke(Style.Border.base, lineWidth: 0.5, antialiased: true) }
                .frame(maxWidth: 540)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

