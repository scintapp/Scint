import AgencyRuntime
import SwiftUI


enum Design {
    enum Border {
        static var block: Color { Color(red: 0.14974, green: 0.14921, blue: 0.15372) }
        static var card: Color { Color(red: 0.14974, green: 0.14921, blue: 0.15372) }
    }

    enum Background {
        static var base: Color { Color(red: 0.10375, green: 0.10044, blue: 0.10752) }
        static var block: Color { Color(red: 0.1273, green: 0.12601, blue: 0.1345) }
        static var card: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var console: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var detail: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var editor: Color { Color(red: 0.1373, green: 0.13601, blue: 0.1385) }
        static var menu: Color { Color(red: 0.10375, green: 0.10044, blue: 0.10752).opacity(0.5) }
        static var palette: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
    }

    enum Foreground {
        static var base: Color { .primary.opacity(0.9) }
        static var caption: Color { .secondary.opacity(0.85) }
        static var disabled: Color { .secondary.opacity(0.5) }
    }

    enum Tint {
        static var compose: Color { Color(red: 1.03119, green: 0.81027, blue: 1.39988) }
        static var dispatch: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var execute: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
        static var observe: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var traverse: Color { Color(red: 0.943, green: 1.201, blue: 1.220) }

        static var inactive: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var active: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var running: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.89311, green: 0.71807, blue: 0.66035) }
        static var error: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var command: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var harness: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var sheet: Color { Color(red: 1.46963, green: 1.08887, blue: 0.98027) }
        static var space: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
        static var task: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
        static var workspace: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
    }
}

enum Theme {
    static let base = Color(red: 0.10144, green: 0.10236, blue: 0.10376)
    static let surface = Color(red: 0.12474, green: 0.12521, blue: 0.13072)
    static let textPrimary = Color(red: 0.89455, green: 0.90097, blue: 0.91164)
    static let textSecondary = Color(red: 0.71396, green: 0.73396, blue: 0.72494)
    static let textTertiary = Color(red: 0.53455, green: 0.52297, blue: 0.53164)
    static let textQuaternary = Color(red: 0.40955, green: 0.40097, blue: 0.41364)
    static let border = Color(red: 0.14974, green: 0.14921, blue: 0.15372)
    static let provider = Design.Tint.artifact
    static let stateBlocked = Design.Tint.sheet
    static let stateFailed = Design.Tint.failed
    static let hairline = border.opacity(0.12)
    static let quoteBar = Design.Tint.artifact
}
