import AppKit
import SwiftUI


/// Sets the scroll edge effect style on the window's titlebar accessories.
///
/// macOS 26.1 moved this decision from the scroll view to the bar above it:
/// `NSTitlebarAccessoryViewController` gained `preferredScrollEdgeEffectStyle`, and SwiftUI's
/// `.toolbar` is backed by one of those controllers. SwiftUI exposes no modifier for it — the only
/// scroll edge APIs it has are `scrollEdgeEffectStyle(_:for:)` and `scrollEdgeEffectHidden(_:for:)`,
/// both on the scroll view — so reaching the controller means going through AppKit.
///
/// The view itself draws nothing; it exists to hold a reference to the window.
struct TitlebarScrollEdgeEffect: NSViewRepresentable {
    let style: NSScrollEdgeEffectStyle

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ view: NSView, context: Self.Context) {
        apply(from: view)
    }

    /// The window is not attached on the first update, and SwiftUI adds its own accessories for the
    /// toolbar after that, so this retries the way `EditorFocusCoordinator` does rather than
    /// assuming either is in place yet.
    private func apply(from view: NSView, attempts: Int = 3) {
        guard let window = view.window, !window.titlebarAccessoryViewControllers.isEmpty else {
            guard attempts > 0 else { return }
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                apply(from: view, attempts: attempts - 1)
            }
            return
        }

        for controller in window.titlebarAccessoryViewControllers {
            controller.preferredScrollEdgeEffectStyle = style
        }
    }
}

extension View {
    func titlebarScrollEdgeEffect(_ style: NSScrollEdgeEffectStyle = .hard) -> some View {
        background(TitlebarScrollEdgeEffect(style: style))
    }
}
