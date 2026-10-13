import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


struct LoadMenu<Label: View>: View {
    @Environment(ScintModel.self) private var scint
    @State private var anchor = PanelAnchor.Box()
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void
    @ViewBuilder let label: () -> Label

    private func open() {
        guard let view = anchor.view, let window = view.window else { return }
        let menu = scint.panels.choices
        menu.items = items
        menu.anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
        menu.onPick = onPick
        menu.state.query = ""
        menu.state.index = 0
        scint.panels.present(menu, in: window)
    }

    var body: some View {
        Button { open() } label: { label() }
            .background(PanelAnchor(box: anchor))
    }
}
