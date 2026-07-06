import Foundation
import SwiftUI
import AgencyRuntime


struct ComposerToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button { } label: {
            ZStack {
                Image(systemName: "text.bubble.badge.sparkles")
                    .foregroundStyle(.primary.opacity(0.8))
                    .blendMode(.sourceAtop)
            }
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct UtilityToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var console = agency.studio.utility

        Button { console.presented.toggle() } label: {
            Image(systemName: "dock.rectangle")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(console.presented ? Color.secondary.opacity(0.8) : Color.primary.opacity(0.85))
                .help(console.presented ? "Hide console." : "Show console.")
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
            agency.studio.navigator.presented.toggle()
            agency.studio.navigator.position = 0
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.left")
                .foregroundStyle(.primary.opacity(0.9))
        }
        .glassEffect(.regular)
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}


struct InspectorToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button {
            agency.studio.inspector.presented.toggle()
            agency.studio.inspector.position = 0
            NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.right")
                .foregroundStyle(.primary.opacity(0.9))
        }
        .glassEffect(.regular)
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

struct DetailToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button { agency.studio.canvas.presented.toggle() } label: {
            Image(systemName: "square.fill.text.grid.1x2")
                .help(agency.studio.canvas.presented ? "Hide space details" : "Show space details")
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct ProcessToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        if agency.studio.inspector.presented {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
                agency.studio.inspector.presented.toggle()
            } label: {
                Image(systemName: "tachometer")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonStyle(.automatic)
            .buttonBorderShape(.circle)
            .labelsHidden()

        } else {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
                agency.studio.inspector.presented.toggle()
            } label: {
                Image(systemName: "tachometer")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonBorderShape(.circle)
            .labelsHidden()
        }
    }
}

struct PickerToggleStyle: ButtonStyle {
    @State private var isHovered = false
    let isSelected: Bool

    private func tint(pressed: Bool) -> Color {
        if pressed { return Color.primary.opacity(0.2) }
        if isSelected { return Color.primary.opacity(0.12) }
        if isHovered { return Color.primary.opacity(0.16) }
        return Color.primary.opacity(0.0)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { isHovered = $0 }
            .background {
                Capsule()
                    .fill(tint(pressed: configuration.isPressed))
                    .frame(maxWidth: 74, maxHeight: 34)
                    .padding([.top, .bottom], 3)
                    .padding([.leading, .trailing], 2.5)
            }
    }
}

struct NavigatorPickerToggle: View {
    @Environment(AgencyModel.self) var agency

    private func button(for context: Navigator.Context, systemImage: String) -> some View {
        let isSelected = agency.studio.navigator.presented && agency.studio.navigator.context == context

        return Button {
            if isSelected { agency.studio.navigator.presented = false }
            else {
                agency.studio.navigator.context = context
                agency.studio.navigator.presented = true
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
            }
        } label: {
            Image(systemName: systemImage)
                .frame(width: 36, height: 36, alignment: .center)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.primary.opacity(0.9))
        }
        .buttonStyle(PickerToggleStyle(isSelected: isSelected))
        .id(String(describing: context))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            button(for: .navigator, systemImage: "cube.transparent")
            button(for: .library, systemImage: "building.classical.columns")
        }
        .frame(width: 74, height: 36)
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
