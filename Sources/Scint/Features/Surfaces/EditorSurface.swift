import SwiftUI


struct EditorSurface: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 24)
            VStack {
                if let sheet = model.session.active {
                    EditorComponent(sheet)
                        .id(sheet)
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
