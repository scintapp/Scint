import SwiftUI


enum Design {
    enum Border {
        static var block: Color { Color(red: 0.14974, green: 0.14921, blue: 0.15372) }
        static var card: Color { Color(red: 0.14974, green: 0.14921, blue: 0.15372) }
        static var hairline: Color { block.opacity(0.12) }
    }

    enum Background {
        static var base: Color { Color(red: 0.10375, green: 0.10044, blue: 0.10752) }
        static var block: Color { Color(red: 0.1273, green: 0.12601, blue: 0.1345) }
        static var card: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var console: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var detail: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var editor: Color { Color(red: 0.1373, green: 0.13601, blue: 0.1385) }
        static var menu: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875).opacity(0.2) }
        static var palette: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var surface: Color { Color(red: 0.12474, green: 0.12521, blue: 0.13072) }
    }

    enum Foreground {
        static var primary: Color { .primary.opacity(0.9) }
        static var secondary: Color { .primary.opacity(0.76) }
        static var tertiary: Color { .secondary.opacity(0.8) }
        static var quaternary: Color { .secondary.opacity(0.66) }
        static var caption: Color { .secondary.opacity(0.9) }
        static var disabled: Color { .secondary.opacity(0.6) }
    }

    enum Tint {
        static var compose: Color { Color(red: 1.031, green: 0.810, blue: 1.399) }
        static var dispatch: Color { Color(red: 1.158, green: 1.007, blue: 1.447) }
        static var execute: Color { Color(red: 1.388, green: 0.817, blue: 0.947) }
        static var observe: Color { Color(red: 0.848, green: 1.004, blue: 1.207) }
        static var traverse: Color { Color(red: 0.920, green: 1.221, blue: 1.343) }

        static var inactive: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var active: Color { Color(red: 0.888, green: 0.954, blue: 1.127) }
        static var running: Color { Color(red: 0.723, green: 0.781, blue: 0.809) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.893, green: 0.718, blue: 0.660) }
        static var error: Color { Color(red: 0.776, green: 0.455, blue: 0.562) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var command: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var harness: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var sheet: Color { Color(red: 1.46963, green: 1.08887, blue: 0.98027) }
        static var space: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
        static var task: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
        static var workspace: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
    }
}
