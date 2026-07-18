import Foundation
import SwiftUI
import AgencyRuntime


struct CanvasButton: View {
    var body: some View {
        SwiftUI.Menu {
//            ForEach(models, id: \.self) { model in
            Button {  } label: { Label("Space", systemImage: "square.grid.2x2") }
            Button {  } label: { Label("Sheet", systemImage: "square.grid.2x2") }
//                .disabled(selection == model)
        } label: {
            Image(systemName: "square.grid.2x2")
                .frame(height: 30, alignment: .center)
                .foregroundStyle(Design.Foreground.secondary)
                .font(.system(size: 13))
        }
        .menuIndicator(.hidden)
        .frame(height: 30, alignment: .center)
        .buttonStyle(.plain)
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
            Iconography.Icon(symbol: symbol, tint: Design.Foreground.secondary, sizing: iconSize)
                .frame(width: controlSize, height: controlSize)
        }
        .help(helpText)
        .buttonStyle(.plain)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Design.Foreground.secondary)
        .background { Circle().fill(fill) }
        .overlay {
            if opensTranscript { Circle().strokeBorder(stroke, lineWidth: 0.75) }
            else { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(stroke, lineWidth: 0.75) }
        }
    }
}

struct ConsoleToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var console = agency.app

        Button { } label: {
            Image(systemName: "dock.rectangle")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Design.Foreground.secondary)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct NavigatorToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button {
            agency.app.navigator.presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.left")
                .foregroundStyle(Design.Foreground.secondary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

struct InspectorToggle: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some View {
        Button {
            presented.toggle()
//            NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.right")
                .foregroundStyle(Design.Foreground.secondary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

//struct PanelToggle<Content: View>: View {
//    @Environment(AgencyModel.self) private var agency
//    let id: String
//    let icon: String
//    @ViewBuilder let content: () -> Content
//
//    private var panel: AnyView { AnyView(BasePanel(content().environment(agency))) }
//
//    var body: some View {
//        Button { agency.panel(id: id, size: CGSize(width: 640, height: 480), view: panel).toggle() } label: {
//            Image(systemName: icon)
//        }
//        .buttonBorderShape(.circle)
//        .buttonBorderShape(.circle)
//        .labelsHidden()
//    }
//}
