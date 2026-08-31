import SwiftUI


struct ComposeToggle: View {
    let panel: ContentPanel

    private var composing: Binding<Bool> {
        Binding(
            get: { panel.surface == .compose },
            set: { selected in panel.surface = selected ? .compose : .edit }
        )
    }

    var body: some View {
        Toggle(isOn: composing) {
            Image(systemName: "ellipsis.bubble")
        }
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
                .foregroundStyle(Style.Foreground.base)
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
                .foregroundStyle(Style.Foreground.base)
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
            Iconography.Icon(symbol: symbol, tint: Style.Foreground.base, sizing: iconSize)
                .frame(width: controlSize, height: controlSize)
        }
        .help(helpText)
        .buttonStyle(.plain)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Style.Foreground.base)
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
                .foregroundStyle(Style.Foreground.base)
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
                model.session.back()
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.session.navigation.canGoBack)
            Button {
                model.session.forward()
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}
