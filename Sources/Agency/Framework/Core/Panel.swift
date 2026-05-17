import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers


@Observable @MainActor final class PanelModel {
    var model: Model = .browse
    var position: CGFloat = 0
    var presented: Bool = true

    enum Model {
        case browse, compose, edit, run
    }

    func params(_ agency: AgencyModel) -> Params {
        .init()
    }

    func controls(_ agency: AgencyModel) -> Controls {
        Controls(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
            }
        )
    }
}

final class FloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() }
        else { super.keyDown(with: event) }
    }
}

struct BasePanel<Content: View>: View {
    let content: Content

    init(_ content: Content) { self.content = content }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.black.opacity(0.5), lineWidth: 1)
                        .blur(radius: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(.clear)
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
                .font(.system(size: 11, weight: .medium))
        }
        .buttonBorderShape(.circle)
    }
}
