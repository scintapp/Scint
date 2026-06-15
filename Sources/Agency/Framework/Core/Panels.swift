import SwiftUI
import AppKit


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
    let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    init(_ content: Content) { self.content = content }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .glassEffect(.regular.tint(.black.opacity(0.25)), in: shape)
                .overlay(shape.stroke(.black.opacity(0.75), lineWidth: 0.75))
                .blur(radius: 1)
            content
        }
        .clipShape(shape)
    }
}

@Observable @MainActor final class PanelModel {
    var model: Model = .search
    var position: CGFloat = 0
    var presented: Bool = true

    enum Model { case composer, dashboard, search }

    func parameters(_ agency: AgencyModel) -> Parameters { .init() }

    func controls(_ agency: AgencyModel) -> Controls {
        .init(
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
