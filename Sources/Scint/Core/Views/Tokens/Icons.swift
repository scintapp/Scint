import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor extension Iconography {
    static let dotSymbol = "circlebadge.fill"
    static let dotScale: CGFloat = 0.7

    static func tint(for intent: ScintRuntimeIntent) -> Style.Tint {
        switch intent {
            case .compose: .compose
            case .dispatch: .dispatch
            case .evaluate: .evaluate
            case .observe: .observe
            case .search: .search
        }
    }

    static func menuTint(for item: MenuItem) -> Color {
        if let ref = item.ref { return accent(for: ref) }
        switch item.commandID {
            case "new-task", "checklist": return Style.Tint.task.bright
            case "new-link", "add-files": return Style.Tint.artifact.bright
            case "heading-1", "heading-2", "heading-3", "quote": return Style.Tint.document.bright
            case "code-block": return Style.Tint.command.bright
            default: return Style.Tint.space.bright
        }
    }

    static func menuTint(for kind: MenuFormKind) -> Color {
        switch kind {
            case .task: Style.Tint.task.bright
            case .link, .artifact: Style.Tint.artifact.bright
            case .command: Style.Tint.command.bright
            case .document: Style.Tint.document.bright
        }
    }

    @ViewBuilder static func menuIcon(for item: MenuItem, selected: Bool) -> some View {
        let icon = item.ref.map { icon(for: $0, size: Metrics.rowIcon) }
        ?? item.icon.map { Icon(symbol: $0, tint: Style.Tint.neutral.bright, sizing: 16) }
        if let icon {
            icon
                .frame(width: 20, height: 20)
                .opacity(selected ? 1 : Style.Opacity.pressed)
        }
    }
}

extension Context.State {
    static let ordered: [Self] = [.failed, .working, .active, .completed, .inactive]

    var label: String {
        switch self {
            case .inactive: "Inactive"
            case .active: "Active"
            case .working: "Working"
            case .completed: "Completed"
            case .failed: "Needs Attention"
        }
    }

    var running: Bool { self == .active || self == .working }
}

typealias ScintRuntimeIntent = Intent
