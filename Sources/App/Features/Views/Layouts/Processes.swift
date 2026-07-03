import SwiftUI


private enum RunState: String, CaseIterable, Identifiable {
    case active = "Active"
    case running = "Running"
    case blocked = "Blocked"
    case failed = "Failed"

    var id: String { rawValue }

    var symbol: String {
        switch self {
            case .active: return "circle.fill"
            case .running: return "progress.indicator"
            case .blocked: return "pause.circle"
            case .failed: return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
            case .active: return Design.Tint.active
            case .running: return Design.Tint.running
            case .blocked: return Design.Tint.blocked
            case .failed: return Design.Tint.failed
        }
    }
}

private struct RunSample: Identifiable {
    let id = UUID()
    let state: RunState
    let title: String
    let latestSummary: String
    let time: String
    let badges: [String]
    let actions: [String]
}

private enum RunSampleData {
    static let runs: [RunSample] = [
        RunSample(
            state: .active,
            title: "Runtime API Migration",
            latestSummary: "Implemented provider property migration.",
            time: "4:49",
            badges: ["2/3 tasks", "1 file"],
            actions: ["Pause", "Stop", "Transcript"]
        ),
        RunSample(
            state: .active,
            title: "Testing",
            latestSummary: "Validated runtime suite progress.",
            time: "2:17",
            badges: ["14/22 passed", "3 suites"],
            actions: ["Pause", "Stop", "Transcript"]
        ),
        RunSample(
            state: .running,
            title: "Fixture Rewrite",
            latestSummary: "Rewrote focus mode fixtures.",
            time: "0:53",
            badges: ["1 command", "Focus Mode"],
            actions: ["Pause", "Stop", "Transcript"]
        ),
        RunSample(
            state: .blocked,
            title: "Model Surface Audit",
            latestSummary: "Requested write access approval.",
            time: "2m",
            badges: ["Approval", "AgencyTools/"],
            actions: ["Approve", "Stop", "Transcript"]
        ),
        RunSample(
            state: .failed,
            title: "Preview Validation",
            latestSummary: "Failed to load the preview skill.",
            time: "40s",
            badges: ["Invalid YAML", "1 error"],
            actions: ["Resume", "Transcript"]
        )
    ]
}

private struct ActionButton: View {
    let title: String
    var iconOnly = false
    let onAction: (String) -> Void

    private var symbol: String {
        switch title {
            case "Approve": return "checkmark"
            case "Pause": return "pause"
            case "Resume": return "play.fill"
            case "Stop": return "stop"
            case "Transcript": return "doc.text"
            default: return "ellipsis"
        }
    }

    var body: some View {
        Button {
            onAction(title)
        } label: {
            if iconOnly {
                Image(systemName: symbol)
                    .frame(width: 18, height: 18)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    Text(title)
                }
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(iconOnly ? .circle : .capsule)
        .controlSize(.small)
        .help(title)
    }
}

private struct OpenButton: View {
    let onAction: (String) -> Void

    var body: some View {
        Button {
            onAction("Open")
        } label: {
            Text("Open")
                .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
}

private struct ProcessRow: View {
    let state: RunState
    let title: String
    let summary: String
    let time: String
    let badges: [String]
    let actions: [String]
    let onAction: (String) -> Void

    private var contextActions: [String] {
        actions.filter { $0 != "Transcript" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Badge(symbol: state.symbol, tint: state.tint)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)

                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                Text(time)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Badge(state.rawValue, tint: state.tint)
            }

            HStack(spacing: 6) {
                ActionButton(title: "Transcript", iconOnly: true, onAction: onAction)

                ForEach(badges, id: \.self) { badge in
                    Badge(badge, style: .neutral)
                }

                Spacer()

                ForEach(contextActions, id: \.self) { action in
                    ActionButton(title: action, onAction: onAction)
                }

                OpenButton(onAction: onAction)
            }
        }
        .padding()
    }
}

struct Processes: View {
    private let runs = RunSampleData.runs
    @State private var filter: RunState?

    private var visibleRuns: [RunSample] {
        guard let filter else { return runs }
        return runs.filter { $0.state == filter }
    }

    private var filterLabels: [(String, String)] {
        [("All", "\(runs.count)")]
            + RunState.allCases.map { state in
                (state.rawValue, "\(runs.filter { $0.state == state }.count)")
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleRuns) { run in
                        ProcessRow(
                            state: run.state,
                            title: run.title,
                            summary: run.latestSummary,
                            time: run.time,
                            badges: run.badges,
                            actions: run.actions,
                            onAction: { _ in }
                        )

                        if run.id != visibleRuns.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func selectFilter(_ label: String) {
        filter = RunState.allCases.first { $0.rawValue == label }
    }
}
