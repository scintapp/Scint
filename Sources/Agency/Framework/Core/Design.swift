import Foundation
import SwiftUI
import AgencyRuntime


enum TypeScale {
    static let avatarMonogram: CGFloat = 16
    static let spaceTitle: CGFloat = 14
    static let spaceChevron: CGFloat = 11
    static let sidebarIcon: CGFloat = 15
    static let sidebarText: CGFloat = 13
    static let sidebarAddIcon: CGFloat = 20
    static let pageTitle: CGFloat = 18
    static let sectionTitle: CGFloat = 15
    static let sectionSubtitle: CGFloat = 11
    static let columnHeader: CGFloat = 11
    static let rowTitle: CGFloat = 14
    static let rowMeta: CGFloat = 13
    static let cardTitle: CGFloat = 13
    static let cardMeta: CGFloat = 11
    static let badgeCheck: CGFloat = 10
}

enum LayoutScale {
    static let sidebarHeaderSpacing: CGFloat = 10
    static let sidebarSpaceSpacing: CGFloat = 6
    static let sidebarHeaderHorizontal: CGFloat = 14
    static let sidebarHeaderTop: CGFloat = 14
    static let sidebarHeaderBottom: CGFloat = 8
    static let sidebarListHorizontal: CGFloat = 4
    static let sidebarRowSpacing: CGFloat = 4
    static let sidebarRowVertical: CGFloat = 2
    static let sidebarRowLeading: CGFloat = 0
    static let sidebarRowTrailing: CGFloat = 0

    static let detailStackSpacing: CGFloat = 18
    static let detailTitleTop: CGFloat = 12
    static let detailHorizontal: CGFloat = 20
    static let detailBottom: CGFloat = 20

    static let listStackSpacing: CGFloat = 18
    static let listSectionSpacing: CGFloat = 24
    static let listGroupSpacing: CGFloat = 10
    static let listRowSpacing: CGFloat = 8
    static let listHeaderBottom: CGFloat = 8
    static let listDividerHorizontal: CGFloat = 12
    static let listRowLeadingWidth: CGFloat = 34
    static let listFolderColumn: CGFloat = 180
    static let listUpdatedColumn: CGFloat = 180
    static let listAuthorColumn: CGFloat = 110
    static let listArtworkSpacing: CGFloat = 14
    static let listRowHorizontal: CGFloat = 10
    static let listRowVertical: CGFloat = 8

    static let gridStackSpacing: CGFloat = 22
    static let gridSectionSpacing: CGFloat = 14
    static let gridColumnMin: CGFloat = 180
    static let gridColumnMax: CGFloat = 210
    static let gridColumnSpacing: CGFloat = 22
    static let gridRowSpacing: CGFloat = 22

    static let cardStackSpacing: CGFloat = 8
    static let cardTextSpacing: CGFloat = 4
    static let tagHorizontal: CGFloat = 8
    static let tagVertical: CGFloat = 3
}

enum Design {
    enum SheetEntry {
        static let background = Color(red: 0.09875, green: 0.09875, blue: 0.09875)
        static let card = Color(red: 0.09875, green: 0.09875, blue: 0.09875)
        static let cardHeader   = Color(red: 0.071, green: 0.067, blue: 0.063)
        static let stroke = Color.white.opacity(0.08)
        static let accent = Color(red: 0.847, green: 0.624, blue: 0.376)
        static let accentSoft = Color(red: 0.847, green: 0.624, blue: 0.376).opacity(0.14)
        static let textPrimary = Color(red: 0.93, green: 0.92, blue: 0.90)
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary = Color.white.opacity(0.35)
        static let codeBlockBg = Color(red: 0.063, green: 0.059, blue: 0.055)
    }

    enum Component {
        static func icon(for ref: Reference) -> String {
            switch ref.type {
            case is Artifact.Type:
                let entry = Artifact.with(ref, { $0.entry })
                switch entry {
                case .app: return "app"
                case .file: return "doc"
                case .http: return "bookmark"
                case .image: return "photo"
                case .script: return "scroll"
                case .skill: return "sparkles"
                case .exec: return "terminal"
                default: return "archivebox"
                }
            case is Control.Type: return "terminal"
            case is Service.Type: return "app.connected.to.app.below.fill"
            case is Workspace.Type: return "cube.transparent"
            case is Space.Type: return "square.split.bottomrightquarter"
            case is Sheet.Type: return "text.alignleft"
            case is Transcript.Type: return "bubble.left.and.text.bubble.right"
            case is Route.Type: return "point.3.connected.trianglepath.dotted"
            default: return "app.grid"
            }
        }
    }

    struct Badge {
        let color: Color
        var border: Color { color.opacity(0.17) }
        var background: Color { color.opacity(0.06) }
        var foreground: Color { color.opacity(0.88) }
    }

    enum Background {
        static var content: Color { Color(red: 0.10175, green: 0.10144, blue: 0.10352) }
        static var console: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var panel: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var card: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
    }

    enum Tint {
        static var input: Color { Color(red: 0.780, green: 0.840, blue: 1.205) }
        static var tasks: Color { Color(red: 1.25884, green: 0.84799, blue: 0.94741) }
        static var output: Color { Color(red: 1.03119, green: 0.81027, blue: 1.39988) }

        static var ready: Color { Color(red: 0.530, green: 0.720, blue: 0.680) }
        static var active: Color { Color(red: 0.568, green: 0.419, blue: 0.517) }
        static var blocked: Color { Color(red: 0.560, green: 0.430, blue: 0.280) }
        static var inactive: Color { Color(red: 0.500, green: 0.480, blue: 0.580) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.88311, green: 0.71807, blue: 0.56035) }
        static var error: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var success: Color { Color(red: 0.62598, green: 0.74072, blue: 0.90186) }
        static var failure: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var control: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var service: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var structure: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
        static var sheet: Color { Color(red: 1.46963, green: 1.08887, blue: 0.98027) }
        static var task: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
    }
}
