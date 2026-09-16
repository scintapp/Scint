import AppKit
import OrderedCollections
import SwiftUI


struct Float<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .glassEffect(.regular, in: Style.Shape.panel)
            .background(Style.Background.overlay.opacity(Style.Opacity.faint))
            .overlay(Style.Shape.panel.stroke(.black.opacity(Style.Opacity.muted), lineWidth: 1))
            .clipShape(Style.Shape.panel)
    }
}

@Observable @MainActor final class PanelModel {
    private(set) var coordinators: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]

    let actions: ActionsPanel = .init()
    let search: SearchPanel = .init()

    func panel(for key: PanelKey) -> any Panel {
        switch key {
            case .actions: actions
            case .search: search
        }
    }

    func coordinator(for key: PanelKey) -> PanelCoordinator? { coordinators[key] }

    func presented(_ key: PanelKey) -> Bool { coordinators[key]?.isVisible ?? false }

    func toggle(_ key: PanelKey, _ params: PanelParams, _ view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: key, parameters: params, view: view, onVisibilityChange: onVisibilityChange).toggle()
    }

    func show(_ key: PanelKey, _ params: PanelParams, _ view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: key, parameters: params, view: view, onVisibilityChange: onVisibilityChange).show()
    }

    func hide(_ key: PanelKey) { coordinators[key]?.hide() }

    private func coordinator(for key: PanelKey, parameters: PanelParams, view: some View, onVisibilityChange: ((Bool) -> Void)?) -> PanelCoordinator {
        if let existing = coordinators[key] {
            existing.update(parameters)
            return existing
        }

        let host = panel(for: key)
        let coordinator = PanelCoordinator.load(
            params: parameters,
            view: AnyView(Float(content: view)),
            pinned: { [weak host] in host?.state.pinned ?? false },
            onVisibilityChange: onVisibilityChange
        )
        coordinators[key] = coordinator
        return coordinator
    }
}
