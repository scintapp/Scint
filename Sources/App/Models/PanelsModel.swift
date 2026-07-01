import SwiftUI
import AppKit


struct BasePanel<Content: View>: View {
    let content: Content
    let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    init(_ content: Content) { self.content = content }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .glassEffect(.regular.tint(.black.opacity(0.25)), in: shape)
                .overlay(shape.stroke(.black.opacity(0.75), lineWidth: 0.75))
                .blur(radius: 1)
            content
        }
        .clipShape(shape)
    }
}

@Observable @MainActor final class PanelsModel {
    var model: Model = .actions
    var position: CGFloat = 0
    var presented: Bool = true
    var panels: [AnyHashable: PanelCoordinator] = [:]

    enum Model { case actions, composer }

    func parameters(_ agency: AgencyModel) -> Parameters { .init() }

    func controls(_ agency: AgencyModel) -> Controls {
        .init(
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    func panel(_ agency: AgencyModel, id: AnyHashable, size: CGSize) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let  view = AnyView(BasePanel(Search().environment(agency)))
        let new = PanelCoordinator.load(agency: agency, size: size, view: view)
        panels[id] = new
        return new
    }
}
