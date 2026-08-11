import SwiftUI


struct EditorSurface: Surface {
    var host: any Host
    var model: any Model

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 32)
            VStack {
                if let scene = model.session.scene {
                    EditorComponent(scene)
                        .id(scene)
                        .frame(maxWidth: 680, alignment: .topLeading)
                } else {
                    Text("Nothing Open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            Color.clear.frame(height: 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
