import AppKit
import OrderedCollections
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable @MainActor final class PanelModel {
    private(set) var coordinators: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]

    let actions: ActionsPanel = .init()
    let input: InputPanel = .init()
    let search: SearchPanel = .init()

    func makeView<Content: View>(_ content: Content) -> some View {
        content
            .clipShape(Style.Shape.panel)
            .glassEffect(.regular, in: Style.Shape.panel)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .overlay {
                Style.Shape.panel
                    .strokeBorder(.black.opacity(Style.Opacity.border), lineWidth: 0.5)

            }
    }


    func getPanel(for key: PanelKey) -> any Panel {
        switch key {
            case .actions: actions
            case .input: input
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

        let host = getPanel(for: key)
        let coordinator = PanelCoordinator.load(
            params: parameters,
            view: AnyView(makeView(view)),
            pinned: { [weak host] in host?.state.pinned ?? false },
            onVisibilityChange: onVisibilityChange
        )
        coordinators[key] = coordinator
        return coordinator
    }
}
