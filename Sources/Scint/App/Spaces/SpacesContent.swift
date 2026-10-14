import SwiftUI
import ScintRuntime
import ScintComponents


struct InboxContent: Surface {
    var host: any Host
    var model: any Model

    var inbox: Reference { model.session.inbox }

    var body: some View {
        ScrollView {}
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
        .safeAreaBar(edge: .top) { InboxHeader(ref: inbox) }
    }
}
