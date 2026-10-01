import SwiftUI


public struct FrameShape: Shape {
    public var hole: Cutout

    public init(hole: Cutout) {
        self.hole = hole
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(hole.path(in: rect))
        return path
    }
}

public struct Cutout: InsettableShape {
    public var insets: EdgeInsets
    public var radius: CGFloat
    public var amount: CGFloat = 0

    public init(insets: EdgeInsets, radius: CGFloat) {
        self.insets = insets
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        let hole = CGRect(
            x: rect.minX + insets.leading,
            y: rect.minY + insets.top,
            width: rect.width - insets.leading - insets.trailing,
            height: rect.height - insets.top - insets.bottom
        ).insetBy(dx: amount, dy: amount)
        return Path(roundedRect: hole, cornerRadius: max(0, radius - amount), style: .continuous)
    }

    public func inset(by amount: CGFloat) -> Self {
        var hole = self
        hole.amount += amount
        return hole
    }
}
