import OrderedCollections
import SwiftUI


private struct Float<P: Panel>: View {
    let panel: P
    let agency: AgencyModel

    var body: some View {
        panel.surface(agency)
            .environment(agency)
            .glassEffect(.regular, in: Design.Shape.panel)
            .background(Design.Background.panel)
            .overlay(Design.Shape.panel.stroke(.black.opacity(0.5), lineWidth: 0.5))
            .clipShape(Design.Shape.panel)
    }
}

@Observable @MainActor final class PanelController {
    private(set) var coordinators: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]

    func coordinator(for id: AnyHashable) -> PanelCoordinator? { coordinators[id] }
    func presented(_ id: AnyHashable) -> Bool { coordinators[id]?.isVisible ?? false }
    func toggle<P: Panel>(_ panel: P, in agency: AgencyModel) { coordinator(for: panel, in: agency)?.toggle() }
    func show<P: Panel>(_ panel: P, in agency: AgencyModel) {  coordinator(for: panel, in: agency)?.show() }
    func hide<P: Panel>(_ panel: P, in agency: AgencyModel) {  hide(panel.parameters(agency).id) }
    func hide(_ id: AnyHashable) { coordinators[id]?.hide() }

    private func coordinator<P: Panel>(for panel: P, in agency: AgencyModel) -> PanelCoordinator? {
        let params = panel.parameters(agency)
        guard let float = params.panel else { return nil }

        if let existing = coordinators[params.id] {
            existing.update(float)
            return existing
        }

        let coordinator = PanelCoordinator.load(
            params: float,
            view: AnyView(Float(panel: panel, agency: agency)),
            onVisibilityChange: { [weak panel] presented in
                panel?.state.presented = presented
            }
        )
        coordinators[params.id] = coordinator
        return coordinator
    }
}
