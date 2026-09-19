import AppKit
import ScintComponents
import SwiftUI


enum CanvasAxis: String, CaseIterable, Identifiable, Sendable {
    case vertical, horizontal

    var id: String { rawValue }
    var symbol: String { self == .vertical ? "square.split.1x2" : "square.split.2x1" }
    var label: String { self == .vertical ? "Top to bottom" : "Left to right" }
}

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

struct CanvasAnchors: @MainActor PreferenceKey {
    @MainActor static let defaultValue: [AnyHashable: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AnyHashable: Anchor<CGRect>], nextValue: () -> [AnyHashable: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct CanvasBranch<Content: View>: View {
    let ref: Reference
    var axis: CanvasAxis
    let content: (Reference) -> Content

    private var level: AnyLayout {
        axis == .vertical
        ? AnyLayout(VStackLayout(spacing: Metrics.canvasLevelGap))
        : AnyLayout(HStackLayout(spacing: Metrics.canvasLevelGap))
    }

    private var siblings: AnyLayout {
        axis == .vertical
        ? AnyLayout(HStackLayout(alignment: .top, spacing: Metrics.canvasSiblingGap))
        : AnyLayout(VStackLayout(alignment: .leading, spacing: Metrics.canvasSiblingGap))
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
    let refs: [Reference]
    let axis: CanvasAxis
    let frames: [AnyHashable: CGRect]

    var body: some View {
        let stroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        var edges = Path()
        var bridges = Path()
        for ref in refs { tree(ref, &edges, &bridges) }

        return ZStack {
            edges.stroke(Style.Foreground.secondary, style: stroke)
            bridges.stroke(Style.Tint.bridge.bright, style: stroke)
        }
    }

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
        let bar = along(parent).max + Metrics.canvasLevelGap / 2

        for child in Space.with(ref, { $0.spaces }) ?? [] {
            guard let node = frames[child] else { continue }
            edges.move(to: point(along(parent).max, across(parent).mid))
            edges.addLine(to: point(bar, across(parent).mid))
            edges.addArc(
                tangent1End: point(bar, across(node).mid),
                tangent2End: point(along(node).min, across(node).mid),
                radius: Style.Shape.controlRadius
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
            let head = Style.Spacing.detail

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

struct CanvasScroll<Content: View>: NSViewRepresentable {
    let refs: [Reference]
    var axis: CanvasAxis
    var viewport: CanvasViewport
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
            rootView: CanvasTree(refs: refs, axis: axis, content: content, onBackground: onBackground)
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
        scroll.backgroundColor = NSColor(Style.Background.canvas)
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
            refs: refs, axis: axis, content: content, onBackground: onBackground
        )
        scroll.documentView?.needsLayout = true
    }
}

struct CanvasTree<Content: View>: View {
    let refs: [Reference]
    var axis: CanvasAxis
    let content: (Reference) -> Content
    let onBackground: () -> Void

    private var siblings: AnyLayout {
        axis == .vertical
        ? AnyLayout(HStackLayout(alignment: .top, spacing: Metrics.canvasSiblingGap))
        : AnyLayout(VStackLayout(alignment: .leading, spacing: Metrics.canvasSiblingGap))
    }

    var body: some View {
        siblings {
            ForEach(refs, id: \.self) { ref in
                CanvasBranch(ref: ref, axis: axis, content: content)
            }
        }
        .backgroundPreferenceValue(CanvasAnchors.self) { anchors in
            GeometryReader { proxy in
                CanvasLinks(refs: refs, axis: axis, frames: anchors.mapValues { proxy[$0] })
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBackground)
            }
        }
        .fixedSize()
    }
}

struct Canvas<Content: View>: View {
    let refs: [Reference]
    var axis: CanvasAxis
    var viewport: CanvasViewport
    let onBackground: () -> Void

    @ViewBuilder let content: (Reference) -> Content

    var body: some View {
        GeometryReader { proxy in
            CanvasScroll(
                refs: refs,
                axis: axis,
                viewport: viewport,
                insets: proxy.safeAreaInsets,
                onBackground: onBackground,
                content: content
            )
            .ignoresSafeArea()
        }
        .background(Style.Background.canvas)
    }
}

final class CanvasClip: NSClipView {
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
        onScale?(enclosingScrollView?.magnification ?? Metrics.canvasActualSize)
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

final class CanvasDocument: NSView {
    weak var hosted: NSView?

    var insets = NSEdgeInsetsZero

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

    func reflow() {
        guard !reflowing, let hosted, let clip = superview as? NSClipView else { return }
        reflowing = true
        defer { reflowing = false }

        hosted.layoutSubtreeIfNeeded()
        let content = measure(hosted)
        guard content.width > 1, content.height > 1 else { return }

        let margin = CGSize(
            width: max(Metrics.canvasPadding, clip.frame.width / 2),
            height: max(Metrics.canvasPadding, clip.frame.height / 2)
        )
        let frame = CGRect(origin: CGPoint(x: margin.width, y: margin.height), size: content)
        let bounds = CGSize(width: content.width + margin.width * 2, height: content.height + margin.height * 2)
        let shift = CGPoint(x: frame.minX - hosted.frame.minX, y: frame.minY - hosted.frame.minY)

        if frame != hosted.frame { hosted.frame = frame }
        if abs(bounds.width - self.frame.width) > 0.5 || abs(bounds.height - self.frame.height) > 0.5 {
            setFrameSize(bounds)
        }

        if !anchored {
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

    private func anchor(_ frame: CGRect, in clip: NSClipView) {
        let visible = clip.bounds.size
        let origin: CGPoint = switch axis {
            case .vertical: CGPoint(
                x: frame.midX - visible.width / 2 - (insets.left - insets.right) / 2,
                y: frame.minY - insets.top - Metrics.canvasPadding
            )
            case .horizontal: CGPoint(
                x: frame.minX - insets.left - Metrics.canvasPadding,
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

@MainActor @Observable final class CanvasViewport {
    static let minimum: CGFloat = 0.35
    static let maximum: CGFloat = 1.75

    private(set) var scale: CGFloat = Metrics.canvasActualSize

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

    func zoom(_ direction: CGFloat) {
        guard let scroll else { return }
        let bounds = scroll.contentView.bounds
        let offset = CanvasInsets.offset(insets, magnification: scroll.magnification)
        apply(
            scroll.magnification + direction * Metrics.canvasZoomStep,
            focus: CGPoint(x: bounds.midX + offset.x, y: bounds.midY + offset.y)
        )
    }

    func fit() {
        guard let scroll, let document else { return }
        let clip = scroll.contentView.frame.size
        let viewport = CGSize(
            width: clip.width - insets.left - insets.right,
            height: clip.height - insets.top - insets.bottom
        )
        let target = document.contentFrame.insetBy(dx: -Metrics.canvasPadding, dy: -Metrics.canvasPadding)
        guard viewport.width > 0, viewport.height > 0, target.width > 0, target.height > 0 else { return }

        let scale = min(viewport.width / target.width, viewport.height / target.height)
        apply(min(scale, Metrics.canvasActualSize), focus: CGPoint(x: target.midX, y: target.midY))
    }

    func actual() {
        guard let scroll else { return }
        let bounds = scroll.contentView.bounds
        let offset = CanvasInsets.offset(insets, magnification: scroll.magnification)
        apply(Metrics.canvasActualSize, focus: CGPoint(x: bounds.midX + offset.x, y: bounds.midY + offset.y))
    }

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
