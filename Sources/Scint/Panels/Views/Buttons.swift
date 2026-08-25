import SwiftUI


struct ContentPicker: View {
    let panel: ContentPanel

    private func selection(for surface: ContentPanel.ContentSurface) -> Binding<Bool> {
        Binding(
            get: { panel.state.presented && panel.surface == surface },
            set: { selected in
                if selected {
                    panel.surface = surface
                    panel.state.presented = true
                } else if panel.surface == surface {
                    panel.state.presented = false
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(ContentPanel.ContentSurface.allCases) { surface in
                Toggle(isOn: selection(for: surface)) {
                    Image(systemName: surface.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.primary)
        .tint(Color(Style.Background.button))
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
                .foregroundStyle(Style.Foreground.secondary)
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
                .foregroundStyle(Style.Foreground.secondary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

struct ActionButton: View {
    let title: String
    let onAction: (String) -> Void

    var symbol: String {
        switch title {
            case "Approve": return "checkmark"
            case "Pause": return "pause"
            case "Resume": return "play.fill"
            case "Stop": return "stop"
            case "Open": return "text.bubble"
            default: return "ellipsis"
        }
    }

    var opensTranscript: Bool { title == "Open" }
    var controlSize: CGFloat { opensTranscript ? 27 : 25 }
    var iconSize: CGFloat { opensTranscript ? 10.5 : 10 }
    var fill: Color { Color.primary.opacity(opensTranscript ? 0.065 : 0.07) }
    var stroke: Color { Color.primary.opacity(opensTranscript ? 0.09 : 0.08) }
    var helpText: String { opensTranscript ? "Open transcript" : title }

    var body: some View {
        Button { onAction(title) } label: {
            Iconography.Icon(symbol: symbol, tint: Style.Foreground.secondary, sizing: iconSize)
                .frame(width: controlSize, height: controlSize)
        }
        .help(helpText)
        .buttonStyle(.plain)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Style.Foreground.secondary)
        .background { Circle().fill(fill) }
        .overlay {
            if opensTranscript { Circle().strokeBorder(stroke, lineWidth: 0.75) }
            else { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(stroke, lineWidth: 0.75) }
        }
    }
}

struct MaterialButton: View {
    var body: some View {
        SwiftUI.Menu {
            Button {  } label: { Label("Space", systemImage: "square.grid.2x2") }
            Button {  } label: { Label("Material", systemImage: "square.grid.2x2") }
        } label: {
            Image(systemName: "square.grid.2x2")
                .frame(height: 30, alignment: .center)
                .foregroundStyle(Style.Foreground.secondary)
                .font(.system(size: 13))
        }
        .menuIndicator(.hidden)
        .frame(height: 30, alignment: .center)
        .buttonStyle(.plain)
    }
}

struct NavigationButtons: View {
    let model: any Model

    var body: some View {
        ControlGroup {
            Button {
                if let selection = model.session.back() {
                    if let content = selection.content, content.type is Material.Type { model.focus(content) }
                    else if let structure = selection.space { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.session.navigation.canGoBack)
            Button {
                if let selection = model.session.forward() {
                    if let content = selection.content, content.type is Material.Type { model.focus(content) }
                    else if let structure = selection.space { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}
