import SwiftUI


struct PanelFrame: Shape {
    var hole: PanelHole

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(hole.path(in: rect))
        return path
    }
}

struct PanelHole: InsettableShape {
    var insets: EdgeInsets
    var radius: CGFloat
    var amount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let hole = CGRect(
            x: rect.minX + insets.leading,
            y: rect.minY + insets.top,
            width: rect.width - insets.leading - insets.trailing,
            height: rect.height - insets.top - insets.bottom
        ).insetBy(dx: amount, dy: amount)
        return Path(roundedRect: hole, cornerRadius: max(0, radius - amount), style: .continuous)
    }

    func inset(by amount: CGFloat) -> Self {
        var hole = self
        hole.amount += amount
        return hole
    }
}
