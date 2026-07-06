import AgencyRuntime
import SwiftUI


enum RunSampleData {
    static let runs: [RunSample] = [
        RunSample(
            state: .active,
            intent: .execute,
            title: "Runtime API Migration",
            latestSummary: "Implemented provider property migration.",
            time: "4:49",
            actions: ["Pause", "Stop", "Open"]
        ),
        RunSample(
            state: .running,
            intent: .dispatch,
            title: "Fixture Rewrite",
            latestSummary: "Rewriting focus mode fixtures against latest runtime.",
            time: "0:53",
            actions: ["Pause", "Stop", "Open"]
        ),
        RunSample(
            state: .blocked,
            intent: .observe,
            title: "Model Surface Audit",
            latestSummary: "Awaiting schema confirmation from @l.vance.",
            time: "12m",
            actions: ["Approve", "Stop", "Open"]
        ),
        RunSample(
            state: .failed,
            intent: .execute,
            title: "Preview Validation",
            latestSummary: "Failed to load the preview skill.",
            time: "40s",
            actions: ["Resume", "Open"]
        ),
        RunSample(
            state: .completed,
            intent: .traverse,
            title: "Discovery Prep",
            latestSummary: "Context gathered for 3 leads.",
            time: "done",
            actions: ["Open"]
        )
    ]
}

enum RunState: String, CaseIterable, Identifiable {
    case active = "Active"
    case running = "Running"
    case blocked = "Blocked"
    case failed = "Failed"
    case completed = "Completed"

    var id: String { rawValue }

    var badgeSymbol: String {
        switch self {
            case .active: return Iconography.Custom.active.rawValue
            case .running: return Iconography.Custom.running.rawValue
            case .blocked: return Iconography.Custom.blocked.rawValue
            case .failed: return Iconography.Custom.failed.rawValue
            case .completed: return Iconography.Custom.completed.rawValue
        }
    }

    var tint: Color {
        switch self {
            case .active: return Design.Tint.active
            case .running: return Design.Tint.running
            case .blocked: return Design.Tint.blocked
            case .failed: return Design.Tint.failed
            case .completed: return Design.Tint.inactive
        }
    }
}

enum RunIntent: String {
    case compose = "Compose"
    case dispatch = "Dispatch"
    case execute = "Execute"
    case observe = "Observe"
    case traverse = "Traverse"

    var modality: Harness.Modality {
        switch self {
            case .compose: return .compose
            case .dispatch: return .dispatch
            case .execute: return .execute
            case .observe: return .observe
            case .traverse: return .traverse
        }
    }

    @MainActor var tint: Color {
        Iconography.icon(for: modality).tint
    }
}

struct RunSample: Identifiable {
    let id = UUID()
    let state: RunState
    let intent: RunIntent
    let title: String
    let latestSummary: String
    let time: String
    let actions: [String]
}

struct ProcessCard: View {
    let state: RunState
    let intent: RunIntent
    let title: String
    let summary: String
    let time: String
    let actions: [String]
    let selected: Bool
    let onSelect: () -> Void
    let onAction: (String) -> Void

    var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
    var hasTranscriptAction: Bool { actions.contains("Open") }
    var contextActions: [String] { actions.filter { $0 != "Open" } }
    var intentIcon: Iconography.Icon { Iconography.icon(for: intent.modality, size: 13) }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary)
                        .lineLimit(1)
                }


                HStack {
                    Text(time)
                        .font(.system(size: 10.5, weight: .light, design: .monospaced))
                        .foregroundStyle(state.tint.opacity(state == .completed ? 0.7 : 0.96))
                        .lineLimit(1)
                    intentIcon.frame(width: 18, height: 18)
                }
                .frame(width: 30, alignment: .topTrailing)
                .help(intent.rawValue)
            }
            .frame(height: 28)

            VStack(alignment: .leading) {
                Text(summary)
                    .lineLimit(3)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(alignment: .top)
            }
            .frame(height: 48)

            HStack(spacing: 4) {
                if hasTranscriptAction { ActionButton(title: "Open", onAction: onAction) }
                Spacer()
                ForEach(contextActions, id: \.self) { action in ActionButton(title: action, onAction: onAction) }
            }
            .frame(height: 26)
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(alignment: .topLeading)
        .contentShape(shape)
        .onTapGesture { onSelect() }
        .background { shape.fill(Design.Background.base) }
        .overlay { shape.fill(intent.tint.opacity(0.015)) }
        .background { shape.glassEffect(.clear, in: shape) }
        .overlay { shape.strokeBorder(Design.Foreground.primary.opacity(0.06), lineWidth: 1.0) }
        .overlay { shape.strokeBorder(intent.tint.opacity(0.12), lineWidth: 0.5) }
    }
}

struct ProcessColumn: View {
    @State  var selected: RunSample.ID? = RunSampleData.runs.first { $0.state == .blocked }?.id
    let runs = RunSampleData.runs
    let width: CGFloat = 360
    var selectedRun: RunSample { runs.first { $0.id == selected } ?? runs[0] }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(runs) { run in
                    ProcessCard(
                        state: run.state,
                        intent: run.intent,
                        title: run.title,
                        summary: run.latestSummary,
                        time: run.time,
                        actions: run.actions,
                        selected: selectedRun.id == run.id,
                        onSelect: { selected = run.id },
                        onAction: { _ in }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollIndicators(.hidden)
    }
}

struct Processes: View {
    @Environment(AgencyModel.self) var agency
    let columns = Array(0..<6)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 24) {
                ForEach(columns, id: \.self) { _ in ProcessColumn() }
            }
            .background { Design.Background.console }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollIndicators(.hidden)
        }
    }
}
