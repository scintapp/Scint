import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class PanelModel: Model {
    let app: AppModel
    let search = SearchPanel()
    let actions = ActionsPanel()
    let editor = EditorMenu()
    let choices = ChoiceMenu()
    let floating = PanelProvider()
    let anchored = PanelProvider()
    var session: Session

    init(_ app: AppModel, _ session: Session) {
        self.app = app
        self.session = session
    }

    func toggle(_ key: PanelKey) {
        switch key {
            case .actions: toggle(actions)
            case .search: toggle(search)
        }
    }

    func present(_ menu: some Menu, in window: NSWindow, onDismiss: @escaping () -> Void = {}) {
        show(menu, menu.surface(self), in: anchored, window, onDismiss)
    }

    func dismiss(_ host: any Host) {
        guard host.state.presented else { return }
        (host is any Panel ? floating : anchored).hide()
    }

    private func toggle(_ panel: some Panel) {
        if panel.state.presented { return floating.hide() }
        show(panel, panel.surface(self), in: floating, nil) {}
    }

    private func show(_ host: any Host, _ view: some View, in provider: PanelProvider, _ window: NSWindow?, _ onDismiss: @escaping () -> Void) {
        guard let params = host.parameters(self).panel else { return }
        if provider.visible, !host.state.presented { provider.onVisibility(false) }
        provider.onVisibility = { visible in
            host.state.presented = visible
            if !visible { onDismiss() }
        }
        provider.onCancel = { host.controls(self).onInput?(.cancel) ?? false }
        provider.show(params, view, in: window)
    }
}
