import SwiftUI


struct Style {
    enum Shape {
        // Named separately because a layer needs the number, not the shape: anything hosting
        // SwiftUI in an AppKit window has to round its own backing to match.
        static let tinyRadius: CGFloat = 9
        static let smallRadius: CGFloat = 14
        static let mediumRadius: CGFloat = 17
        static let largeRadius: CGFloat = 20
        static let panelRadius: CGFloat = 30

        static var tiny: RoundedRectangle { RoundedRectangle(cornerRadius: tinyRadius, style: .continuous) }
        static var small: RoundedRectangle { RoundedRectangle(cornerRadius: smallRadius, style: .continuous) }
        static var medium: RoundedRectangle { RoundedRectangle(cornerRadius: mediumRadius, style: .continuous) }
        static var large: RoundedRectangle { RoundedRectangle(cornerRadius: largeRadius, style: .continuous) }
        static var panel: RoundedRectangle { RoundedRectangle(cornerRadius: panelRadius, style: .continuous) }
        static var capsule: Capsule { Capsule() }
    }

    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32

        static let rowHeight: CGFloat = 26
        static let rowDetailHeight: CGFloat = 36

        static let contentMaxWidth: CGFloat = 660
        static let cardHeight: CGFloat = 64
        static let listIndent: CGFloat = 16
        static let menuWidth: CGFloat = 256
        static let menuListHeight: CGFloat = 336
        static let menuFormHeight: CGFloat = 160
    }

    enum Dimension {
        static let border: CGFloat = 1
        static let icon: CGFloat = 14
        static let iconLarge: CGFloat = 20
        static let control: CGFloat = 32
        static let taskRowMinHeight: CGFloat = 56
        static let assignmentDescriptionHeight: CGFloat = 112

        static let taskPanel = CGSize(width: 860, height: 560)
        static let taskPanelMinimum = CGSize(width: 640, height: 420)
        static let assignmentPanel = CGSize(width: 720, height: 430)
        static let assignmentPanelMinimum = CGSize(width: 560, height: 360)

        static let canvasNode = CGSize(width: 224, height: 96)
        static let canvasSiblingGap: CGFloat = 40
        static let canvasLevelGap: CGFloat = 72
        static let canvasPadding: CGFloat = 64
    }

    enum Scale {
        static let identity: CGFloat = 1
        static let minimum: CGFloat = 0.5
        static let maximum: CGFloat = 1.6
        static let step: CGFloat = 0.15
    }

    enum Limit {
        static let singleLine = 1
        static let doubleLine = 2
        static let cardBadges = 3
    }

    enum Border {
        static var base: Color { Color(red: 0.18824, green: 0.18824, blue: 0.19216) }
        static var group: Color { Color(red: 0.24008, green: 0.24033, blue: 0.24057) }
        static var raised: Color { Color(red: 0.20008, green: 0.20033, blue: 0.20057) }
    }

    enum Opacity {
        static let full = 1.0
        static let strong = 0.82
        static let muted = 0.6
        static let faint = 0.38
        static let washed = 0.06
        static let hairline = 0.04
        static let disabled = 0.086
    }

    enum Duration {
        static let menuSelection = 0.1
        static let interaction = 0.18
    }

    enum Background {
        static var base: Color { Color(red: 0.097196, green: 0.097196, blue: 0.099118) }
        static var panel: Color { Color(red: 0.11313, green: 0.11333, blue: 0.11355) }
        static var surface: Color { Color(red: 0.13725, green: 0.13725, blue: 0.14118) }
        static var group: Color { Color(red: 0.18821, green: 0.18821, blue: 0.19124).opacity(0.5) }
        static var form: Color { Color(red: 0.12821, green: 0.12821, blue: 0.12124).opacity(0.5) }
        static var card: Color { Color(red: 0.39181, green: 0.39198, blue: 0.39291).opacity(0.05) }
        static var control: Color { Color(red: 0.72821, green: 0.72821, blue: 0.73124).opacity(0.5) }
        static var raised: Color { Color(red: 0.12821, green: 0.12821, blue: 0.13124) }
        static var overlay: Color { Color(red: 0.162, green: 0.165, blue: 0.169) }
    }

    enum Foreground {
        static var base: Color { Color(red: 0.908, green: 0.912, blue: 0.924) }
        static var secondary: Color { Color(red: 0.83891, green: 0.84939, blue: 0.86086) }
        static var subtle: Color { Color(red: 0.73891, green: 0.74939, blue: 0.76086) }
        static var muted: Color { Color(red: 0.60891, green: 0.60939, blue: 0.61086) }
        static var faint: Color { Color(red: 0.49099, green: 0.49147, blue: 0.4927) }
        static var disabled: Color { Color(red: 0.23721, green: 0.23818, blue: 0.23977) }
    }

    enum Tint {
        static var accent: Color { Color(red: 0.60784, green: 0.69804, blue: 0.82745) }
        static var artifact: Color { Color(red: 0.92549, green: 0.82353, blue: 0.93333) }
        static var command: Color { Color(red: 0.82353, green: 0.50784, blue: 0.69804) }
        static var harness: Color { Color(red: 0.82353, green: 0.50784, blue: 0.69804) }
        static var material: Color { Color(red: 0.97294, green: 0.84314, blue: 0.75294) }
        static var transcript: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var task: Color { Color(red: 0.9443, green: 0.7645, blue: 0.7823) }
        static var space: Color { Color(red: 0.892, green: 0.729, blue: 0.892) }
        static var bridge: Color { Color(red: 0.892, green: 0.729, blue: 0.892) }
        static var alert: Color { Color(red: 0.812, green: 0.545, blue: 0.545) }

        enum Intent {
            static var compose: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
            static var dispatch: Color { Color(red: 0.878, green: 0.639, blue: 0.435) }
            static var evaluate: Color { Color(red: 0.867, green: 0.541, blue: 0.639) }
            static var observe: Color { Color(red: 0.612, green: 0.678, blue: 0.816) }
            static var search: Color { Color(red: 0.545, green: 0.788, blue: 0.596) }
        }
    }
}
