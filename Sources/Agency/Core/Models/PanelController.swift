import OrderedCollections
import AppKit
import SwiftUI


@Observable @MainActor final class PanelController {
    var panels: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]
    var query: String = ""
    var index: Int = 0

    enum Model { case sidebar, split, floating  }

    func panel(_ agency: AgencyModel, id: AnyHashable, size: CGSize, view: some View) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let coordinator = PanelCoordinator.load(agency, size: size, view: AnyView(view))
        panels[id] = coordinator
        return coordinator
    }

    func togglePanel(_ agency: AgencyModel, content: some View) {
        let view = AnyView(Float(content.environment(agency)))
        panel(agency, id: "panel", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    private func panel(_ agency: AgencyModel, id: AnyHashable, size: CGSize, view: @autoclosure () -> AnyView) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let new = PanelCoordinator.load(agency, size: size, view: view())
        panels[id] = new
        return new
    }

    struct Float<Content: View>: View {
        let content: Content

        init(_ content: Content) { self.content = content }

        var body: some View {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .glassEffect(.regular/*.tint(.black.opacity(0.25))*/, in: Design.Shape.panel)
                    .overlay(Design.Shape.panel.stroke(.black.opacity(0.75), lineWidth: 0.75))
                    .blur(radius: 1)
                content
            }
            .clipShape(Design.Shape.panel)
        }
    }
}

