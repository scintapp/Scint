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
        static let background = Design.Background.content
        static let card = Design.Background.panel
        static let cardHeader = Color.primary.opacity(0.06)
        static let stroke = Color.primary.opacity(0.1)
        static let accent = Color.secondary
        static let accentSoft = Color.primary.opacity(0.06)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
        static let codeBlockBg = Color.primary.opacity(0.08)
    }

    enum Component {
        static func icon(for ref: Reference) -> String {
            switch ref.type {
            case is Artifact.Type: if let entry = Artifact.with(ref, { $0 })?.entry { return Design.Component.icon(for: entry) }
            case is Control.Type: return "switch.2"
            case is Route.Type: return "app.connected.to.app.below.fill"
            case is Service.Type: return "gear"
            case is Sheet.Type: for entry in Sheet.with(ref, { $0.entries }) ?? [] { return Design.Component.icon(for: entry) }
            case is Transcript.Type: for entry in Transcript.with(ref, { $0.entries }) ?? [] { return Design.Component.icon(for: entry) }
            case is Space.Type: return "app"
            case is Workspace.Type: return "cube.transparent"
            default: return "app.grid"
            }
            return "app.grid"
        }

        static func icon(for entry: Artifact.Entry) -> String {
            switch entry {
            case .app: return "square.grid.2x2.fill"
            case .file: return "folder"
            case .http: return "doc.badge.ellipsis"
            case .image: return "photo"
            case .script: return "chevron.left.forwardslash.chevron.right"
            case .skill: return "shippingbox"
            case .exec: return "terminal"
            }
        }

        static func icon(for entry: Sheet.Entry) -> String {
            switch entry {
            case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref): return Component.icon(for: ref)
            case .content: return "text.alignleft"
            case .task: return "checkmark.app"
            }
        }

        static func icon(for entry: Transcript.Entry) -> String {
            switch entry {
            case .event: return "23.calendar"
            case .sheet(let ref, _): return Self.icon(for: ref)
            case .transcript(let ref, _, _): return Component.icon(for: ref)
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
        static var output: Color { Color(red: 1.03119, green: 0.81027, blue: 1.39988) }

        static var active: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var observing: Color { Color(red: 0.890, green: 0.9, blue: 1.00) }
        static var running: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var ready: Color { Color(red: 0.530, green: 0.720, blue: 0.680) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.89311, green: 0.71807, blue: 0.66035) }
        static var error: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var success: Color { Color(red: 0.62598, green: 0.74072, blue: 0.90186) }
        static var failure: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var control: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var service: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var structure: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
        static var sheet: Color { Color(red: 1.46963, green: 1.08887, blue: 0.98027) }
        static var task: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
    }
}
