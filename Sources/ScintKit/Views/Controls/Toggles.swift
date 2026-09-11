import SwiftUI


struct ItemToggle: View {
    let isOn: Bool
    let onChange: () -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { _ in onChange() }))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
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
            Image(systemName: "sidebar.squares.right")
                .foregroundStyle(Style.Foreground.primary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}
