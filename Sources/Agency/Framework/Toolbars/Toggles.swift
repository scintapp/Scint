import AgencyRuntime
import AppKit
import SwiftUI




struct NavigatorToggle: View {
    @Binding var presented: Bool

    init(presented: Binding<Bool>) { _presented = presented }

    var body: some View {
        if presented {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                presented.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonStyle(.automatic)
            .buttonBorderShape(.circle)
            .labelsHidden()

        } else {
            Button { presented.toggle() } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonBorderShape(.circle)
            .labelsHidden()
        }
    }
}

struct InspectorToggle: View {
    @Binding var presented: Bool

    init(presented: Binding<Bool>) { _presented = presented }

    var body: some View {
        if presented {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                presented.toggle()
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonStyle(.automatic)
            .buttonBorderShape(.circle)
            .labelsHidden()

        } else {
            Button { presented.toggle() } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonBorderShape(.circle)
            .labelsHidden()
        }
    }
}

struct ConsoleToggle: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some View {
        Button { agency.studio.console.presented.toggle() } label: {
            Image(systemName: "dock.rectangle")
                .frame(maxWidth: 28, maxHeight: 28, alignment: .center)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(presented ? Color.secondary.opacity(0.8) : Color.primary.opacity(0.85))
                .help(presented ? "Hide console." : "Show console.")
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct DetailsToggle: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some View {
        Button { agency.studio.content.presented.toggle() } label: {
            Image(systemName: "square.fill.text.grid.1x2")
                .help(presented ? "Hide boundary details" : "Show boundary details")
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct PanelToggle<Content: View>: View {
    @Environment(AgencyModel.self) private var agency
    let id: String
    let icon: String
    @ViewBuilder let content: () -> Content

    private var panel: AnyView { AnyView(BasePanel(content().environment(agency))) }

    var body: some View {
        Button { agency.panel(id: id, size: CGSize(width: 640, height: 480), view: panel).toggle() } label: {
            Image(systemName: icon)
        }
        .buttonBorderShape(.circle)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}
