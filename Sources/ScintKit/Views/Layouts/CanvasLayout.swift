import AppKit
import SwiftUI


@MainActor struct CanvasAnchors: @MainActor PreferenceKey {
    static let defaultValue: [AnyHashable: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AnyHashable: Anchor<CGRect>], nextValue: () -> [AnyHashable: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// The direction the tree grows in. Everything else is expressed relative to it.
enum CanvasAxis: String, CaseIterable, Identifiable, Sendable {
    case vertical, horizontal

    var id: String { rawValue }
    var symbol: String { self == .vertical ? "square.split.1x2" : "square.split.2x1" }
    var label: String { self == .vertical ? "Top to bottom" : "Left to right" }
}

struct CanvasBranch<Content: View>: View {
    let ref: Reference
    let axis: CanvasAxis
    let content: (Reference) -> Content

    /// Both arrangements are the same stack transposed, so AnyLayout keeps node identity across a flip.
    private var level: AnyLayout {
        axis == .vertical
            ? AnyLayout(VStackLayout(spacing: Style.Dimension.canvasLevelGap))
            : AnyLayout(HStackLayout(spacing: Style.Dimension.canvasLevelGap))
    }

    private var siblings: AnyLayout {
        axis == .vertical
            ? AnyLayout(HStackLayout(alignment: .top, spacing: Style.Dimension.canvasSiblingGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: Style.Dimension.canvasSiblingGap))
    }

    var body: some View {
        level {
            content(ref)
                .anchorPreference(key: CanvasAnchors.self, value: .bounds) { [AnyHashable(ref): $0] }

            let children = Array(Space.with(ref) { $0.spaces } ?? [])
            siblings {
                ForEach(children, id: \.self) { child in
                    CanvasBranch(ref: child, axis: axis, content: content)
                }
            }
        }
    }
}

struct CanvasLinks: View {
    let ref: Reference
    let axis: CanvasAxis
    let frames: [AnyHashable: CGRect]

    var body: some View {
        let stroke = StrokeStyle(lineWidth: Style.Dimension.border, lineCap: .round, lineJoin: .round)
        var edges = Path()
        var bridges = Path()
        tree(ref, &edges, &bridges)

        return ZStack {
            edges.stroke(Style.Foreground.faint, style: stroke)
            bridges.stroke(Style.Tint.bridge, style: stroke)
        }
    }

    // Tree-relative geometry. `along` runs in the growth direction, `across` runs perpendicular to it,
    // so one set of path code serves a tree that grows downward and one that grows to the trailing edge.
    private func along(_ rect: CGRect) -> (min: CGFloat, max: CGFloat, mid: CGFloat) {
        axis == .vertical ? (rect.minY, rect.maxY, rect.midY) : (rect.minX, rect.maxX, rect.midX)
    }

    private func across(_ rect: CGRect) -> (min: CGFloat, max: CGFloat, mid: CGFloat) {
        axis == .vertical ? (rect.minX, rect.maxX, rect.midX) : (rect.minY, rect.maxY, rect.midY)
    }

    private func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
        axis == .vertical ? CGPoint(x: across, y: along) : CGPoint(x: along, y: across)
    }

    private func tree(_ ref: Reference, _ edges: inout Path, _ bridges: inout Path) {
        guard let parent = frames[ref] else { return }
        let bar = along(parent).max + Style.Dimension.canvasLevelGap / 2

        for child in Space.with(ref, { $0.spaces }) ?? [] {
            guard let node = frames[child] else { continue }
            edges.move(to: point(along(parent).max, across(parent).mid))
            edges.addLine(to: point(bar, across(parent).mid))
            edges.addArc(
                tangent1End: point(bar, across(node).mid),
                tangent2End: point(along(node).min, across(node).mid),
                radius: Style.Spacing.md
            )
            edges.addLine(to: point(along(node).min, across(node).mid))
            tree(child, &edges, &bridges)
        }

        for link in Space.with(ref, { $0.bridges }) ?? [] {
            guard let bridge = Bridge.with(link, { $0 }),
                  let origin = frames[bridge.origin],
                  let target = frames[bridge.target]
                    else { continue }
            let side: CGFloat = across(target).mid >= across(origin).mid ? 1 : -1
            let start = (along: along(origin).mid, across: side > 0 ? across(origin).max : across(origin).min)
            let end = (along: along(target).mid, across: side > 0 ? across(target).min : across(target).max)
            let bend = abs(end.across - start.across) / 2
            let head = Style.Spacing.sm

            bridges.move(to: point(start.along, start.across))
            bridges.addCurve(
                to: point(end.along, end.across),
                control1: point(start.along, start.across + side * bend),
                control2: point(end.along, end.across - side * bend)
            )
            bridges.move(to: point(end.along - head, end.across - side * head))
            bridges.addLine(to: point(end.along, end.across))
            bridges.addLine(to: point(end.along + head, end.across - side * head))
        }
    }
}

/// The tree and its connectors, hosted as a single unit so both pan and scale together.
struct CanvasTree<Content: View>: View {
    let ref: Reference
    let axis: CanvasAxis
    let content: (Reference) -> Content
    let onBackground: () -> Void

    var body: some View {
        CanvasBranch(ref: ref, axis: axis, content: content)
            .backgroundPreferenceValue(CanvasAnchors.self) { anchors in
                GeometryReader { proxy in
                    CanvasLinks(ref: ref, axis: axis, frames: anchors.mapValues { proxy[$0] })
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onBackground)
                }
            }
            .fixedSize()
    }
}

/// Viewport state for one canvas. Local to the window, never shared with domain models.
@MainActor @Observable final class CanvasViewport {
    static let minimum: CGFloat = 0.35
    static let maximum: CGFloat = 1.75

    /// Mirrors AppKit's magnification so the readout can follow a live pinch.
    private(set) var scale: CGFloat = Style.Scale.identity

    var percentage: String { "\(Int((scale * 100).rounded()))%" }

    @ObservationIgnored fileprivate weak var scroll: NSScrollView?
    @ObservationIgnored fileprivate weak var document: CanvasDocument?

    fileprivate func bind(_ scroll: NSScrollView, _ document: CanvasDocument?) {
        self.scroll = scroll
        self.document = document
    }

    fileprivate func track(_ magnification: CGFloat) {
        guard abs(magnification - scale) > 0.001 else { return }
        scale = magnification
    }

    private var insets: NSEdgeInsets { document?.insets ?? NSEdgeInsetsZero }

    /// Steps magnification about the centre of whatever the bars leave visible.
    func zoom(_ direction: CGFloat) {
        guard let scroll else { return }
        let bounds = scroll.contentView.bounds
        let offset = CanvasInsets.offset(insets, magnification: scroll.magnification)
        apply(
            scroll.magnification + direction * Style.Scale.step,
            focus: CGPoint(x: bounds.midX + offset.x, y: bounds.midY + offset.y)
        )
    }

    /// Frames the whole tree with padding, never magnifying past 100%.
    func fit() {
        guard let scroll, let document else { return }
        let clip = scroll.contentView.frame.size
        let viewport = CGSize(
            width: clip.width - insets.left - insets.right,
            height: clip.height - insets.top - insets.bottom
        )
        let target = document.contentFrame.insetBy(dx: -Style.Dimension.canvasPadding, dy: -Style.Dimension.canvasPadding)
        guard viewport.width > 0, viewport.height > 0, target.width > 0, target.height > 0 else { return }

        let scale = min(viewport.width / target.width, viewport.height / target.height)
        apply(min(scale, Style.Scale.identity), focus: CGPoint(x: target.midX, y: target.midY))
    }

    /// Returns to 100% around whatever is currently centered in the uncovered part of the viewport.
    func actual() {
        guard let scroll else { return }
        let bounds = scroll.contentView.bounds
        let offset = CanvasInsets.offset(insets, magnification: scroll.magnification)
        apply(Style.Scale.identity, focus: CGPoint(x: bounds.midX + offset.x, y: bounds.midY + offset.y))
    }

    /// Magnifies to `scale`, then centers `focus` — a point in document coordinates — between the bars.
    private func apply(_ scale: CGFloat, focus: CGPoint) {
        guard let scroll else { return }
        let clip = scroll.contentView
        let magnification = min(max(scale, scroll.minMagnification), scroll.maxMagnification)
        scroll.magnification = magnification

        let visible = CGSize(width: clip.frame.width / magnification, height: clip.frame.height / magnification)
        let offset = CanvasInsets.offset(insets, magnification: magnification)
        clip.scroll(to: CGPoint(x: focus.x - visible.width / 2 - offset.x, y: focus.y - visible.height / 2 - offset.y))
        scroll.reflectScrolledClipView(clip)
        track(magnification)
    }
}

/// The canvas fills the window so the toolbar and composer have content to float over. These convert
/// the safe area they cover into document-space corrections, so framing still targets what stays visible.
enum CanvasInsets {
    static func offset(_ insets: NSEdgeInsets, magnification: CGFloat) -> CGPoint {
        guard magnification > 0 else { return .zero }
        return CGPoint(
            x: (insets.left - insets.right) / (2 * magnification),
            y: (insets.top - insets.bottom) / (2 * magnification)
        )
    }

    static func make(_ insets: EdgeInsets) -> NSEdgeInsets {
        NSEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}

/// Keeps the document centred whenever it is smaller than the visible area.
final class CanvasClip: NSClipView {
    /// Reports live magnification; the clip's bounds resize whenever the scroll view scales.
    var onScale: ((CGFloat) -> Void)?

    private var watching = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !watching else { return }
        watching = true
        postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scaled), name: NSView.boundsDidChangeNotification, object: self
        )
    }

    @objc private func scaled() {
        onScale?(enclosingScrollView?.magnification ?? Style.Scale.identity)
    }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let document = documentView else { return rect }

        let magnification = rect.height > 0 ? frame.height / rect.height : 1
        let insets = (document as? CanvasDocument)?.insets ?? NSEdgeInsetsZero
        let offset = CanvasInsets.offset(insets, magnification: magnification)

        if rect.width > document.frame.width { rect.origin.x = (document.frame.width - rect.width) / 2 - offset.x }
        if rect.height > document.frame.height { rect.origin.y = (document.frame.height - rect.height) / 2 - offset.y }
        return rect
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        documentView?.needsLayout = true
    }
}

/// Sizes itself to the hosted tree plus margins, so there is always room to pan around the content.
final class CanvasDocument: NSView {
    weak var hosted: NSView?

    /// How much of the viewport the toolbar and composer cover. The canvas draws beneath them.
    var insets = NSEdgeInsetsZero

    /// Flipping the growth direction reshapes the tree entirely, so the opening framing is earned again.
    var axis: CanvasAxis = .vertical {
        didSet {
            guard axis != oldValue else { return }
            anchored = false
            settled = nil
            needsLayout = true
        }
    }

    private struct Settling: Equatable {
        let viewport: CGRect
        let top: CGFloat
        let origin: CGPoint
    }

    private var settled: Settling?
    private var anchored = false
    private var reflowing = false

    /// Clicks that miss every node reach the document, since AppKit delivers mouseDown to one view only.
    var onBackground: (() -> Void)?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onBackground?()
    }

    var contentFrame: CGRect { hosted?.frame ?? bounds }

    override func layout() {
        super.layout()
        reflow()
    }

    /// Measures the hosted tree, resizes the document around it and keeps the visible content in place.
    func reflow() {
        guard !reflowing, let hosted, let clip = superview as? NSClipView else { return }
        reflowing = true
        defer { reflowing = false }

        hosted.layoutSubtreeIfNeeded()
        let content = measure(hosted)
        guard content.width > 1, content.height > 1 else { return }

        // Margins follow the viewport frame, not its bounds, so magnifying never resizes the document.
        let margin = CGSize(
            width: max(Style.Dimension.canvasPadding, clip.frame.width / 2),
            height: max(Style.Dimension.canvasPadding, clip.frame.height / 2)
        )
        let frame = CGRect(origin: CGPoint(x: margin.width, y: margin.height), size: content)
        let bounds = CGSize(width: content.width + margin.width * 2, height: content.height + margin.height * 2)
        let shift = CGPoint(x: frame.minX - hosted.frame.minX, y: frame.minY - hosted.frame.minY)

        if frame != hosted.frame { hosted.frame = frame }
        if abs(bounds.width - self.frame.width) > 0.5 || abs(bounds.height - self.frame.height) > 0.5 {
            setFrameSize(bounds)
        }

        if !anchored {
            // SwiftUI reports the safe area over several passes; keep re-anchoring until it settles.
            let settling = Settling(viewport: clip.frame, top: insets.top, origin: frame.origin)
            anchored = settling == settled
            settled = settling
            return anchor(frame, in: clip)
        }

        guard abs(shift.x) > 0.5 || abs(shift.y) > 0.5 else { return }

        let origin = clip.bounds.origin
        clip.scroll(to: CGPoint(x: origin.x + shift.x, y: origin.y + shift.y))
        enclosingScrollView?.reflectScrolledClipView(clip)
    }

    /// Opening position, until `anchored` latches: the root sits clear of the bars, centred across the growth axis.
    private func anchor(_ frame: CGRect, in clip: NSClipView) {
        let visible = clip.bounds.size
        let origin: CGPoint = switch axis {
            case .vertical: CGPoint(
                x: frame.midX - visible.width / 2 - (insets.left - insets.right) / 2,
                y: frame.minY - insets.top - Style.Dimension.canvasPadding
            )
            case .horizontal: CGPoint(
                x: frame.minX - insets.left - Style.Dimension.canvasPadding,
                y: frame.midY - visible.height / 2 - (insets.top - insets.bottom) / 2
            )
        }

        clip.scroll(to: origin)
        enclosingScrollView?.reflectScrolledClipView(clip)
    }

    private func measure(_ view: NSView) -> CGSize {
        let intrinsic = view.intrinsicContentSize
        if intrinsic.width > 0, intrinsic.height > 0 { return intrinsic }

        let fitting = view.fittingSize
        return fitting.width > 0 && fitting.height > 0 ? fitting : view.frame.size
    }
}

struct CanvasScroll<Content: View>: NSViewRepresentable {
    let ref: Reference
    let axis: CanvasAxis
    let viewport: CanvasViewport
    let insets: EdgeInsets
    let onBackground: () -> Void
    @ViewBuilder let content: (Reference) -> Content

    @MainActor final class Coordinator {
        var hosting: NSHostingView<CanvasTree<Content>>?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Self.Context) -> NSScrollView {
        let scroll = NSScrollView()
        let document = CanvasDocument()
        let clip = CanvasClip()
        let hosting = NSHostingView(
            rootView: CanvasTree(ref: ref, axis: axis, content: content, onBackground: onBackground)
        )

        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.autoresizingMask = []
        document.autoresizingMask = []
        document.addSubview(hosting)
        document.hosted = hosting
        document.insets = CanvasInsets.make(insets)
        document.axis = axis
        document.onBackground = onBackground

        clip.onScale = { [weak viewport] magnification in viewport?.track(magnification) }
        scroll.contentView = clip
        scroll.documentView = document
        scroll.automaticallyAdjustsContentInsets = false
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Style.Background.base)
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .allowed
        scroll.verticalScrollElasticity = .allowed
        scroll.usesPredominantAxisScrolling = false
        scroll.allowsMagnification = true
        scroll.minMagnification = CanvasViewport.minimum
        scroll.maxMagnification = CanvasViewport.maximum

        context.coordinator.hosting = hosting
        viewport.bind(scroll, document)
        document.needsLayout = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Self.Context) {
        let document = scroll.documentView as? CanvasDocument
        document?.insets = CanvasInsets.make(insets)
        document?.axis = axis
        document?.onBackground = onBackground
        viewport.bind(scroll, document)
        context.coordinator.hosting?.rootView = CanvasTree(
            ref: ref, axis: axis, content: content, onBackground: onBackground
        )
        scroll.documentView?.needsLayout = true
    }
}

/// Floating capsule the canvas controls sit in, matching the composer's material.
struct CanvasPill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Style.Spacing.xs) { content }
            .padding(.horizontal, Style.Spacing.sm)
            .frame(height: 32)
            .background {
                Style.Shape.capsule
                    .fill(Style.Background.card.opacity(0.5))
                    .glassEffect(.regular, in: Style.Shape.capsule)
            }
            .overlay {
                Style.Shape.capsule
                    .strokeBorder(Style.Border.card.opacity(0.75), lineWidth: Style.Dimension.border)
            }
            .clipShape(Style.Shape.capsule)
            .padding(Style.Spacing.lg)
    }
}

struct CanvasControl: View {
    let symbol: String
    let help: String
    var bordered = false
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? Style.Foreground.primary : Style.Foreground.subtle)
                .frame(width: 24, height: 24)
                .background {
                    if active {
                        Style.Shape.tiny.fill(Style.Background.control)
                    } else if bordered {
                        Style.Shape.tiny.strokeBorder(Style.Border.card, lineWidth: Style.Dimension.border)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct CanvasZoom: View {
    let viewport: CanvasViewport

    var body: some View {
        CanvasPill {
            CanvasControl(symbol: "minus", help: "Zoom out") { viewport.zoom(-1) }

            Button { viewport.actual() } label: {
                Text(viewport.percentage)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Style.Foreground.primary)
                    .frame(width: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reset to 100%")

            CanvasControl(symbol: "plus", help: "Zoom in") { viewport.zoom(1) }

            Divider().frame(height: 14)

            CanvasControl(symbol: "viewfinder", help: "Fit tree", bordered: true) { viewport.fit() }
        }
    }
}

struct CanvasPresentation: View {
    @Binding var axis: CanvasAxis

    var body: some View {
        CanvasPill {
            ForEach(CanvasAxis.allCases) { option in
                CanvasControl(symbol: option.symbol, help: option.label, active: axis == option) {
                    axis = option
                }
            }
        }
    }
}

struct CanvasLayout<Content: View>: View {
    let ref: Reference
    @Binding var axis: CanvasAxis
    let onBackground: () -> Void
    @ViewBuilder let content: (Reference) -> Content

    @State private var viewport = CanvasViewport()

    init(
        ref: Reference,
        axis: Binding<CanvasAxis>,
        onBackground: @escaping () -> Void,
        @ViewBuilder content: @escaping (Reference) -> Content
    ) {
        self.ref = ref
        self._axis = axis
        self.onBackground = onBackground
        self.content = content
    }

    var body: some View {
        // The scroll view ignores the safe area so the toolbar and composer keep floating over the
        // canvas; the insets it reports back keep framing and anchoring clear of them.
        GeometryReader { proxy in
            CanvasScroll(
                ref: ref,
                axis: axis,
                viewport: viewport,
                insets: proxy.safeAreaInsets,
                onBackground: onBackground,
                content: content
            )
                .ignoresSafeArea()
                .overlay(alignment: .bottomLeading) { CanvasZoom(viewport: viewport) }
                .overlay(alignment: .bottomTrailing) { CanvasPresentation(axis: $axis) }
        }
        .background(Style.Background.base)
    }
}
