import SwiftUI


struct Style {
    enum Shape {
        static var small: RoundedRectangle { RoundedRectangle(cornerRadius: 9, style: .continuous) }
        static var medium: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
        static var large: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
        static var panel: RoundedRectangle { RoundedRectangle(cornerRadius: 30, style: .continuous) }
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

        static let contentMaxWidth: CGFloat = 660
        static let cardHeight: CGFloat = 64
        static let listIndent: CGFloat = 54
        static let menuWidth: CGFloat = 256
        static let menuListHeight: CGFloat = 336
        static let menuFormHeight: CGFloat = 160
    }

    enum Limit {
        static let singleLine = 1
        static let doubleLine = 2
        static let cardBadges = 3
    }

    enum Border {
        static var base: Color { Color(red: 0.19008, green: 0.19033, blue: 0.19057) }
        static var group: Color { Color(red: 0.24008, green: 0.24033, blue: 0.24057) }
        static var raised: Color { Color(red: 0.20008, green: 0.20033, blue: 0.20057) }
    }

    enum Opacity {
        static let full = 1.0
        static let muted = 0.6
        static let faint = 0.38
        static let washed = 0.06
        static let hairline = 0.04
        static let disabled = 0.86
    }

    enum Duration {
        static let menuSelection = 0.1
    }

    enum Background {
        static var page: Color { Color(red: 0.10191, green: 0.10231, blue: 0.10271) }
        static var panel: Color { Color(red: 0.10191, green: 0.10191, blue: 0.10191) }
        static var control: Color { Color(red: 0.12821, green: 0.12821, blue: 0.13124) }
        static var raised: Color { Color(red: 0.14821, green: 0.14821, blue: 0.15124) }
        static var group: Color { Color(red: 0.18821, green: 0.18821, blue: 0.19124).opacity(0.25) }
        static var overlay: Color { Color(red: 0.162, green: 0.165, blue: 0.169) }
    }

    enum Foreground {
        static var base: Color { Color(red: 0.908, green: 0.912, blue: 0.924) }
        static var subtle: Color { Color(red: 0.73891, green: 0.74939, blue: 0.76086) }
        static var muted: Color { Color(red: 0.60891, green: 0.60939, blue: 0.61086) }
        static var faint: Color { Color(red: 0.49099, green: 0.49147, blue: 0.4927) }
        static var disabled: Color { Color(red: 0.23721, green: 0.23818, blue: 0.23977) }
    }

    enum Tint {
        static var artifact: Color { Color(red: 0.892, green: 0.892, blue: 0.892) }
        static var command: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var harness: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var material: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var transcript: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var task: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var space: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
        static var bridge: Color { Color(red: 0.892, green: 0.829, blue: 0.892) }
    }
}
