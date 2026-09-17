import SwiftUI


struct Style {
    enum Shape {
        static let codeRadius: CGFloat = 5
        static let tinyRadius: CGFloat = 9
        static let smallRadius: CGFloat = 13
        static let holeRadius: CGFloat = 14.5
        static let mediumRadius: CGFloat = 16.5
        static let largeRadius: CGFloat = 20
        static let panelRadius: CGFloat = 30

        static var tiny: RoundedRectangle { RoundedRectangle(cornerRadius: tinyRadius, style: .continuous) }
        static var small: RoundedRectangle { RoundedRectangle(cornerRadius: smallRadius, style: .continuous) }
        static var hole: RoundedRectangle { RoundedRectangle(cornerRadius: holeRadius, style: .continuous) }
        static var medium: RoundedRectangle { RoundedRectangle(cornerRadius: mediumRadius, style: .continuous) }
        static var large: RoundedRectangle { RoundedRectangle(cornerRadius: largeRadius, style: .continuous) }
        static var panel: RoundedRectangle { RoundedRectangle(cornerRadius: panelRadius, style: .continuous) }
        static var capsule: Capsule { Capsule() }
    }

    enum Spacing {
        static let markdownLineSpacing: CGFloat = 4
        static let markdownBlockSpacing: CGFloat = 12
        static let markdownListSpacing: CGFloat = .zero
        static let markdownListInset: CGFloat = 4
        static let transcriptEntrySpacing: CGFloat = 24
        static let markdownTextInset: CGFloat = 2
        static let markdownTableHorizontal: CGFloat = 8
        static let markdownTableVertical: CGFloat = 6
        static let xxs: CGFloat = 1
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
        static let inputMaxHeight: CGFloat = 256
        static let inputMinHeight: CGFloat = 40
    }

    enum Dimension {
        static let markdownBullet: CGFloat = 4
        static let markdownQuoteBar: CGFloat = 3
        static let markdownColumnWidth: CGFloat = 200
        static let hairline: CGFloat = 0.5
        static let border: CGFloat = 1
        static let icon: CGFloat = 14
        static let iconLarge: CGFloat = 20
        static let control: CGFloat = 32
        static let taskRowMinHeight: CGFloat = 56
        static let assignmentDescriptionHeight: CGFloat = 112
        static let transcriptMaxWidth: CGFloat = 680

        static let taskPanel = CGSize(width: 860, height: 560)
        static let taskPanelMinimum = CGSize(width: 640, height: 420)
        static let inspectorPopover = CGSize(width: 340, height: 620)
        static let assignmentPanel = CGSize(width: 720, height: 430)
        static let assignmentPanelMinimum = CGSize(width: 560, height: 360)

        static let canvasNode = CGSize(width: 224, height: 96)
        static let canvasSiblingGap: CGFloat = 40
        static let canvasLevelGap: CGFloat = 72
        static let canvasPadding: CGFloat = 64
        static let canvasIcon: CGFloat = 24
    }

    enum Scale {
        static let transcriptInputWidth: CGFloat = 0.68
        static let identity: CGFloat = 1
        static let minimum: CGFloat = 0.5
        static let maximum: CGFloat = 1.6
        static let step: CGFloat = 0.15
    }

    enum Limit {
        static let activityMessageLines = 5
        static let singleLine = 1
        static let doubleLine = 2
        static let cardBadges = 3
    }

    enum Border {
        static var base: Color { Color(red: 0.18824, green: 0.18824, blue: 0.19216) }
        static var card: Color { Color(red: 0.27255, green: 0.27647, blue: 0.28039) }
        static var bubble: Color { Color(red: 0.19608, green: 0.21569, blue: 0.27451) }
        static var handle: Color { Color(red: 0.32255, green: 0.32255, blue: 0.32255).opacity(0.75) }
        static var divider: Color { Color(red: 0.20353, green: 0.20475, blue: 0.20745) }
        static var node: Color { Color(red: 0.23922, green: 0.24314, blue: 0.24706) }
        static var group: Color { Color(red: 0.26008, green: 0.26033, blue: 0.26057).opacity(0.5) }
        static var raised: Color { Color(red: 0.20008, green: 0.20033, blue: 0.20057) }
        static var field: Color { Color(red: 0.888, green: 0.888, blue: 0.888).opacity(0.25) }
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
        static var void: Color { Color(red: 0.082353, green: 0.082453, blue: 0.082653) }
        static var base: Color { Color(red: 0.10588, green: 0.10588, blue: 0.1098) }
        static var glass: Color { Color(red: 0.11113, green: 0.11113, blue: 0.11113) }
        static var node: Color { Color(red: 0.13333, green: 0.13333, blue: 0.13725) }
        static var bubble: Color { Color(red: 0.14902, green: 0.16078, blue: 0.20784) }
        static var panel: Color { Color(red: 0.11313, green: 0.11333, blue: 0.11355) }
        static var surface: Color { Color(red: 0.13725, green: 0.13725, blue: 0.14118) }
        static var group: Color { Color(red: 0.19821, green: 0.19821, blue: 0.20124).opacity(0.6) }
        static var form: Color { Color(red: 0.12821, green: 0.12821, blue: 0.12124).opacity(0.5) }
        static var card: Color { Color(red: 0.11588, green: 0.11588, blue: 0.1198) }
        static var control: Color { Color(red: 0.72821, green: 0.72821, blue: 0.73124).opacity(0.2) }
        static var selected: Color { Color(red: 0.72821, green: 0.72821, blue: 0.73124).opacity(0.2) }
        static var raised: Color { Color(red: 0.12821, green: 0.12821, blue: 0.13474) }
        static var overlay: Color { Color(red: 0.162, green: 0.165, blue: 0.169) }
        static var field: Color { Color(red: 0.888, green: 0.888, blue: 0.888).opacity(0.1) }
    }

    enum Foreground {
        static var primary: Color { Color(red: 0.908, green: 0.912, blue: 0.924) }
        static var secondary: Color { Color(red: 0.83891, green: 0.84939, blue: 0.86086) }
        static var subtle: Color { Color(red: 0.73891, green: 0.74939, blue: 0.76086) }
        static var muted: Color { Color(red: 0.60891, green: 0.60939, blue: 0.61086) }
        static var faint: Color { Color(red: 0.49099, green: 0.49147, blue: 0.4927) }
        static var placeholder: Color { Color(red: 0.27721, green: 0.27721, blue: 0.27721) }
        static var disabled: Color { Color(red: 0.23721, green: 0.23818, blue: 0.23977) }
    }

    enum Tint {
        static var accent: Color { Color.accent }
        static var artifact: Color { Color(red: 0.72294, green: 0.84843, blue: 0.9749) }
        static var command: Color { Color(red: 0.96353, green: 0.84784, blue: 0.98804) }
        static var harness: Color { Color(red: 0.96353, green: 0.84784, blue: 0.98804) }
        static var material: Color { Color(red: 0.97294, green: 0.75314, blue: 0.65294) }
        static var transcript: Color { Color(red: 0.94294, green: 0.77314, blue: 0.64294) }
        static var task: Color { Color(red: 0.9443, green: 0.7645, blue: 0.7823) }
        static var space: Color { Color(red: 0.892, green: 0.912, blue: 0.962) }
        static var closure: Color { space }
        static var bridge: Color { Color(red: 0.892, green: 0.729, blue: 0.892) }
        static var alert: Color { Color(red: 0.812, green: 0.545, blue: 0.545) }

        enum Intent {
            static var compose: Color { Color(red: 0.782, green: 0.638, blue: 0.906) }
            static var dispatch: Color { Color(red: 0.978, green: 0.709, blue: 0.535) }
            static var evaluate: Color { Color(red: 0.947, green: 0.641, blue: 0.669) }
            static var observe: Color { Color(red: 0.672, green: 0.889, blue: 0.952) }
            static var search: Color { Color(red: 0.775, green: 0.988, blue: 0.796) }
        }
    }
}
