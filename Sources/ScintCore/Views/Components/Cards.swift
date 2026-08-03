import SwiftUI


 enum DashboardSampleData {
    static let suggestions = [
        "What changed since my last session?",
        "Find stale source assumptions",
        "Draft the next client intake runbook"
    ]

    static let signals = [
        DashboardSignal(
            tone: .blocked,
            title: "Preview validation failed in Operations Utility.",
            detail: "The failing run references one invalid YAML artifact and is safe to inspect from console.",
            action: "Open"
        ),
        DashboardSignal(
            tone: .warning,
            title: "Source Reliability Notes has not been touched in 6 days.",
            detail: "Three live sheets depend on it for citation and evidence standards.",
            action: "Review"
        ),
        DashboardSignal(
            tone: .ready,
            title: "Client Intake is ready for the next discovery call.",
            detail: "Commands, tasks, and nested briefing sheets are assembled.",
            action: "Continue"
        ),
        DashboardSignal(
            tone: .standard,
            title: "Customer Learning Lab is the highest-salience boundary.",
            detail: "Recent edits, an observer harness, and two policy sheets converge there.",
            action: "Inspect"
        )
    ]

    static let paths = [
        DashboardPath(
            title: "Freelance",
            route: "Client Intake / Discovery Call Prep / Proposal Assembly",
            badge: "8 sheets",
            tint: Design.Tint.sheet
        ),
        DashboardPath(
            title: "Content Practice",
            route: "Repurposing Workflow / Customer Learning Lab / Research Desk",
            badge: "active",
            tint: Design.Tint.observe
        ),
        DashboardPath(
            title: "Operations Utility",
            route: "Runtime migration / Testing / Fixture rewrite / Preview validation",
            badge: "5 runs",
            tint: Design.Tint.blocked
        )
    ]

    static let lanes = [
        DashboardLane(
            title: "Executable Documents",
            symbol: "text.alignleft",
            tint: Design.Tint.sheet,
            items: [
                DashboardLaneItem(
                    title: "Intake Interview Script",
                    detail: "Call-plan runbook with two commands and three unresolved tasks."
                ),
                DashboardLaneItem(
                    title: "Follow-Up Packet Instructions",
                    detail: "Candidate for a dispatch harness and artifact collection."
                )
            ]
        ),
        DashboardLane(
            title: "Harness Entry Points",
            symbol: Iconography.Custom.observe.rawValue,
            tint: Design.Tint.harness,
            items: [
                DashboardLaneItem(
                    title: "Research Briefing Agent",
                    detail: "Observer loaded in Customer Learning Lab with two source sheets."
                ),
                DashboardLaneItem(
                    title: "Local Context Indexer",
                    detail: "Can traverse Documents and summarize changed local files."
                )
            ]
        ),
        DashboardLane(
            title: "Suggested Moves",
            symbol: Iconography.Custom.traverse.rawValue,
            tint: Design.Tint.traverse,
            items: [
                DashboardLaneItem(
                    title: "Open the stale reliability sheet",
                    detail: "It anchors several downstream agent prompts and citations."
                ),
                DashboardLaneItem(
                    title: "Ask for a workspace delta",
                    detail: "Summarize edits, runs, and blocked context since last session."
                )
            ]
        )
    ]
}

 enum DashboardSignalTone {
    case standard
    case warning
    case blocked
    case ready

    var tint: Color {
        switch self {
            case .standard: return Design.Tint.info
            case .warning: return Design.Tint.warning
            case .blocked: return Design.Tint.failed
            case .ready: return Design.Tint.observe
        }
    }

    var symbol: String {
        switch self {
            case .standard: return Iconography.Custom.traverse.rawValue
            case .warning: return Iconography.Custom.dispatch.rawValue
            case .blocked: return Iconography.Custom.blocked.rawValue
            case .ready: return Iconography.Custom.completed.rawValue
        }
    }
}

 struct DashboardSignal: Identifiable {
    let id = UUID()
    let tone: DashboardSignalTone
    let title: String
    let detail: String
    let action: String
}

 struct DashboardPath: Identifiable {
    let id = UUID()
    let title: String
    let route: String
    let badge: String
    let tint: Color
}

 struct DashboardLane: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let tint: Color
    let items: [DashboardLaneItem]
}

 struct DashboardLaneItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

 struct DashboardBriefing: View {
    let signals: [DashboardSignal]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dashboard Briefing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)

                Spacer()

                Text("\(signals.count) signals")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.disabled)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)

            Divider().opacity(0.42)

            VStack(spacing: 0) {
                ForEach(signals) { signal in
                    DashboardSignalRow(signal: signal)

                    if signal.id != signals.last?.id {
                        Divider()
                            .opacity(0.34)
                            .padding(.leading, 55)
                    }
                }
            }
        }
        .background(Design.Background.block.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
    }
}

 struct DashboardSignalRow: View {
    let signal: DashboardSignal

    var body: some View {
        HStack {
            Iconography.Icon(symbol: signal.tone.symbol, tint: signal.tone.tint, sizing: 18)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
                    .lineLimit(2)

                Text(signal.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.Foreground.disabled)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Button {
            } label: {
                Text(signal.action)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 72)
    }
}

 struct DashboardContext: View {
    let paths: [DashboardPath]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Context Atlas")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)

                Spacer()

                Text("topology lens")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.disabled)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)

            Divider().opacity(0.42)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Iconography.Icon(symbol: "cube.transparent", tint: Design.Tint.workspace, sizing: 20)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scint")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Design.Foreground.primary)

                        Text("Root workspace, one process surface, 38 indexed references.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Design.Foreground.disabled)
                            .lineLimit(2)
                    }
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.055))
                        .frame(height: 0.5)
                }

                VStack {
                    ForEach(paths) { path in
                        DashboardPathRow(path: path)
                    }
                }
            }
            .padding(16)
        }
        .background(Design.Background.block.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
    }
}

 struct DashboardPathRow: View {
    let path: DashboardPath

    var body: some View {
        HStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(path.tint.opacity(0.76))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(path.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Design.Foreground.secondary)
                        .lineLimit(1)

                    Spacer()

                    Badge(path.badge, style: .neutral)
                }

                Text(path.route)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Design.Foreground.disabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 1)
        }
        .frame(minHeight: 38)
    }
}

 struct DashboardLaneItemRow: View {
    let item: DashboardLaneItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Design.Foreground.secondary)
                .lineLimit(1)

            Text(item.detail)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Design.Foreground.disabled)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }
}

struct DashboardLaneColumn: View {
    let lane: DashboardLane

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Iconography.Icon(symbol: lane.symbol, tint: lane.tint, sizing: 16)
                Text(lane.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 11)

            ForEach(lane.items) { item in
                DashboardLaneItemRow(item: item)

                if item.id != lane.items.last?.id {
                    Divider().opacity(0.34)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Design.Background.block.opacity(0.44))
    }
}

struct DashboardStart: View {
    let lanes: [DashboardLane]

    let columns = [ GridItem(.adaptive(minimum: 240), spacing: 1, alignment: .top) ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Start From Context")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)

                Spacer()

                Text("not a grid, not a board")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.disabled)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 1) {
                ForEach(lanes) { lane in DashboardLaneColumn(lane: lane) }
            }
            .background(Color.primary.opacity(0.055))
        }
        .background(Design.Background.block.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
        }
    }
}

struct DashboardLayout: View {
    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 440), spacing: 24, alignment: .top)
    ]

    var body: some View {
        HStack {
            ScrollView {
                VStack(alignment: .center, spacing: 18) {
                    Group {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            DashboardContext(paths: DashboardSampleData.paths)
                            DashboardBriefing(signals: DashboardSampleData.signals)
                        }
                        DashboardStart(lanes: DashboardSampleData.lanes)
                    }
                    .frame(maxWidth: 320)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Design.Background.console)
    }
}
