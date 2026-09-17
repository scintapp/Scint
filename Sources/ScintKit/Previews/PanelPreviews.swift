import SwiftUI


#if DEBUG
#Preview("Search Panel — Results") {
    let fixture = PreviewFixture.shared
    let panel = SearchPanel()
    panel.state.query = "research"

    return PreviewPanelFrame(size: CGSize(width: 640, height: 480)) {
        panel.surface(fixture.model)
    }
    .preferredColorScheme(.dark)
}

#Preview("Search Panel — Detail") {
    let fixture = PreviewFixture.shared
    let panel = SearchPanel()
    panel.state.query = "research brief"
    panel.state.cursor = fixture.material
    panel.state.detail = true

    return PreviewPanelFrame(size: CGSize(width: 640, height: 480)) {
        panel.surface(fixture.model)
    }
    .preferredColorScheme(.dark)
}

#Preview("Search Panel — Content") {
    let fixture = PreviewFixture.shared
    let panel = SearchPanel()
    panel.surface = .content
    panel.state.query = ""

    return PreviewPanelFrame(size: CGSize(width: 640, height: 480)) {
        panel.surface(fixture.model)
    }
    .preferredColorScheme(.dark)
}

#Preview("Input Panel") {
    let panel = InputPanel()

    return PreviewPanelFrame(size: CGSize(width: 640, height: 90)) {
        PanelInput(
            value: panel.bindable.query,
            image: "sparkles",
            placeholder: "Ask Scint"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Actions Panel") {
    let panel = ActionsPanel()
    let items = ActionsPanel.PanelSurface.allCases.map {
        ItemParams(key: $0.rawValue, name: $0.label, image: $0.symbol)
    }

    return PreviewPanelFrame(size: CGSize(width: 420, height: 104)) {
        PanelModes(items: items, selection: items.first) { item in
            guard let value = item.key.flatMap(ActionsPanel.PanelSurface.init(rawValue:)) else { return }
            panel.surface = value
        }
        .padding(.top, Style.Spacing.lg)
    }
    .preferredColorScheme(.dark)
}
#endif
