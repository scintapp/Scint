import SwiftUI
import ScintRuntime
import ScintComponents


struct SpacesContent: Surface {
    var host: any Host
    var model: any Model

    var spaces: Reference { model.session.spaces }

    var body: some View {
        ScrollView {}
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
        .safeAreaBar(edge: .top) { SpacesHeader(ref: spaces) }
    }
}
