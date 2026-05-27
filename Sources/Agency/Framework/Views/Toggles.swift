import AgencyRuntime
import AppKit
import SwiftUI


struct NavigatorToggle: View {
    @Environment(AgencyModel.self) var agency
    
    var body: some View {
        if agency.studio.navigator.presented {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                agency.studio.navigator.presented.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonStyle(.automatic)
            .buttonBorderShape(.circle)
            .labelsHidden()
            
        } else {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                agency.studio.navigator.presented.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonBorderShape(.circle)
            .labelsHidden()
        }
    }
}

struct InspectorToggle: View {
    @Environment(AgencyModel.self) var agency
    
    var body: some View {
        if agency.studio.inspector.presented {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleInspector(_:)), to: nil, from: nil)
                agency.studio.inspector.presented.toggle()
            } label: {
                Image(systemName: "info.circle")
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
                Image(systemName: "info.circle")
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .buttonBorderShape(.circle)
            .labelsHidden()
        }
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

struct OutlineToggle: View {
    @Environment(AgencyModel.self) var agency
    
    var body: some View {
        Button { agency.studio.content.presented.toggle() } label: {
            Image(systemName: "square.fill.text.grid.1x2")
                .help(agency.studio.content.presented ? "Hide space details" : "Show space details")
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

struct ComposerToggle: View {
    @Environment(AgencyModel.self) var agency
    
    var body: some View {
        Button { /*agency.toggleComposer()*/ } label: {
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

struct InspectorTogglePicker: View {
    @Environment(AgencyModel.self) var agency
    
    func toggle() -> some View {
        ControlGroup {
            Button {
                agency.openProcessInspector()
            } label: { Image(systemName: "tachometer") }
                .id("processing")
            
            Button {
                agency.studio.inspector.context = .authoring
                agency.studio.inspector.presented = true
            } label: { Image(systemName: "info.circle") }
                .id("authoring")
        }
    }
    
    func picker() -> some View {
        ControlGroup {
            Button {
                if agency.studio.inspector.context == .processing { agency.studio.inspector.presented = false }
                else { agency.openProcessInspector() }
            } label: { Image(systemName: "tachometer") }
                .id("processing")
            
            Button {
                if agency.studio.inspector.context == .authoring { agency.studio.inspector.presented = false }
                else { agency.studio.inspector.context = .authoring }
            } label: { Image(systemName: "info.circle") }
                .id("authoring")
        }
    }
    
    @ViewBuilder var body: some View {
        if agency.studio.inspector.presented == false { toggle() }
        else { picker() }
    }
}
