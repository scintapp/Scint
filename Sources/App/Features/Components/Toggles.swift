import AgencyRuntime
import AppKit
import SwiftUI


struct ComposerToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button { } label: {
            ZStack {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(.primary.opacity(0.8))
                    .blendMode(.sourceAtop)
                Image(systemName: "app.background.dotted")
                    .foregroundStyle(.secondary.opacity(0.9))
            }
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct ConsoleToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var console = agency.studio.console

        Button {
            console.presented.toggle()
            if console.presented, console.position < 30 { console.position = 140 }
        } label: {
            Image(systemName: "dock.rectangle")
                .frame(maxWidth: 28, maxHeight: 28, alignment: .center)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(console.presented ? Color.secondary.opacity(0.8) : Color.primary.opacity(0.85))
                .help(console.presented ? "Hide console." : "Show console.")
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct SidebarToggle: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some View {
        Button {
            presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.leading")
                .foregroundStyle(.primary.opacity(0.9))
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}

struct InspectorToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button {
            agency.studio.inspector.presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.right")
                .foregroundStyle(.primary.opacity(0.9))
        }
        .padding(.horizontal, 1)
        .labelsHidden()
    }
}


struct DetailToggle: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Button { agency.studio.detail.presented.toggle() } label: {
            Image(systemName: "square.fill.text.grid.1x2")
                .help(agency.studio.detail.presented ? "Hide space details" : "Show space details")
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

//struct InspectorButtonStyle: ButtonStyle {
//    let isSelected: Bool
//    @State private var isHovered = false
//
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .onHover { isHovered = $0 }
//            .background {
//                Capsule()
//                    .fill(fillColor(pressed: configuration.isPressed))
//                    .frame(maxWidth: 74, maxHeight: 34)
//                    .padding([.top, .bottom], 3)
//                    .padding([.leading, .trailing], 2.5)
//            }
//    }
//
//    private func fillColor(pressed: Bool) -> Color {
//        if pressed { return Color.primary.opacity(0.2) }
//        if isSelected { return Color.primary.opacity(0.12) }
//        if isHovered { return Color.primary.opacity(0.16) }
//        return Color.primary.opacity(0.0)
//    }
//}

//struct InspectorPickerToggle: View {
//    @Environment(AgencyModel.self) var agency
//
//    private func button(for context: Inspector.Context, systemImage: String) -> some View {
//        let isSelected = agency.studio.inspector.presented
//        && agency.studio.inspector.context == context
//
//        return Button {
//            if isSelected { agency.studio.inspector.presented = false }
//            else {
//                agency.studio.inspector.context = context
//                agency.studio.inspector.presented = true
//            }
//        } label: {
//            Image(systemName: systemImage)
//                .frame(width: 36, height: 36, alignment: .center)
//                .font(.system(size: 18, weight: .light))
//                .foregroundStyle(.primary.opacity(0.9))
//        }
//        .buttonStyle(InspectorButtonStyle(isSelected: isSelected))
//        .id(String(describing: context))
//    }
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 0) {
//            button(for: .processing, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
//            button(for: .inspecting, systemImage: "info.circle")
//        }
//        .frame(width: 74, height: 36)
//        .glassEffect(
//            agency.studio.inspector.presented
//            ? .regular.tint(.black.opacity(0.1))
//            : .identity.tint(.black.opacity(0.0)),
//            in: Capsule()
//        )
//    }
//}
