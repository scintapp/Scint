import SwiftUI
import ScintComponents


struct ItemToggle: View {
    let isOn: Bool
    let onChange: () -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { _ in onChange() }))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
    }
}

struct CanvasToggle: View {
    @Environment(ScintModel.self) var scint
    var isOn: Bool { (scint.app.studio.content.surface == .canvas) }

    var body: some View {
        Toggle(
            "",
            systemImage: "cube.transparent",
            isOn: Binding(get: { isOn }, set: { isOn in
                scint.app.studio.content.surface = isOn ? .canvas : .studio
            }))
        .labelsHidden()
    }
}

struct NavigatorToggle: View {
    @Binding var presented: Bool

    var body: some View {
        Button {
            presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.left")
                .foregroundStyle(Style.Foreground.primary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

struct InspectorToggle: View {
    @Binding var presented: Bool

    var body: some View {
        Button {
            presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(Style.Foreground.primary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}
