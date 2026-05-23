
import AgencyRuntime
import SwiftUI


struct EditorPanel: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        VStack {
            if let sheet = agency.session.sheet {
                Editor(ref: sheet)
                    .safeAreaBar(edge: .top, content: { Color.clear.frame(height: 90) })
                    .textSelection(.enabled)
                    .frame(maxWidth: 720, maxHeight: .infinity)
                    .id(sheet)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}
