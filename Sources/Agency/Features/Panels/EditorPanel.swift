
import AgencyRuntime
import SwiftUI


struct EditorPanel: Panel {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        if let sheet = agency.session.sheet {
            AgencyEditor(ref: sheet)
                .safeAreaBar(edge: .top, content: { Color.clear.frame(height: 90) })
                .textSelection(.enabled)
                .frame(maxWidth: 720, maxHeight: .infinity)
                .id(sheet)
        }
    }
}
