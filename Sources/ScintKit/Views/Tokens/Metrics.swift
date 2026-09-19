import SwiftUI

/// Sizes that belong to Scint's own screens rather than the design system:
/// the canvas, menus, list rows, and the composer.
enum Metrics {
    // Canvas
    static let canvasSiblingGap: CGFloat = 40
    static let canvasLevelGap: CGFloat = 72
    static let canvasPadding: CGFloat = 64
    static let canvasZoomStep: CGFloat = 0.15
    static let canvasActualSize: CGFloat = 1

    // Menus
    static let menuWidth: CGFloat = 256
    static let menuListHeight: CGFloat = 336
    static let menuFormHeight: CGFloat = 160
    static let rowIcon: CGFloat = 16
    static let menuSelection = Animation.easeOut(duration: 0.1)

    // Lists and cards
    static let rowHeight: CGFloat = 26
    static let rowDetailHeight: CGFloat = 36
    static let cardHeight: CGFloat = 64
    static let cardBadges = 3

    // Composer
    static let inputMinHeight: CGFloat = 40
    static let inputMaxHeight: CGFloat = 256

    /// The corner radius of the inspector's cutout.
    static let inspectorHoleRadius: CGFloat = 14.5
}
