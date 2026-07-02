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

@Observable @MainActor final class PaletteModel {
    var query: String = ""
    var index: Int = 0
//    var params: PanelParams { agency.studio.palette.parameters(agency) }
//    var items: [ItemParams] { params.components.flatMap { $0.items } }

    func select(_ delta: Int) {
//        let count = items.count
//        guard count > 0 else { return }
//        index = index + delta + count) % count
    }

    func actions() {
//        guard items.indices.contains(agency.studio.palette.index) else { return }
//        let item = items[index]
//        controls(agency).onSelect?(item)
//        dismiss()
    }

    func content() {
//        guard items.indices.contains(agency.studio.palette.index) else { return }
//        guard let ref = items[agency.studio.palette.index].ref else { return }
    }

    func dismiss() {
//        focused = true
//        reset()
//        agency.panels.panels["search"]?.hide()
    }

    func reset() {
        query = ""
        index = 0
    }
}

@Observable @MainActor final class PanelsModel {
    var model: Model = .palette
    var position: CGFloat = 0
    var presented: Bool = true
    var panels: [AnyHashable: PanelCoordinator] = [:]
    var query: String = ""
    var index: Int = 0

    enum Model { case list, palette, group, table }

    func palette(_ agency: AgencyModel, id: AnyHashable, size: CGSize) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let  view = AnyView(
            BasePanel(
                Palette()
                    .view(agency)
                    .environment(agency)
            )
        )
        let panel = PanelCoordinator.load(agency: agency, size: size, view: view)
        panels[id] = panel
        return panel
    }

    struct Panel<Content: View>: View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let content: Content

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
}
