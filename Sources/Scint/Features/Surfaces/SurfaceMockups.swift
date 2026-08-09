import SwiftUI


struct SpaceCardAction: View {
    let title: String
    let systemImage: String
    var isAccented = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isAccented ? SpacePalette.iconAccent : SpacePalette.primaryText)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SpacePalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAccented ? SpacePalette.selectedControl : SpacePalette.button)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SpacePalette.controlBorder, lineWidth: 1)
        )
    }
}

struct SpaceCard: View {
    let card: SpaceCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(card.title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SpacePalette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 12)
            }

            Text(card.summary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(SpacePalette.secondaryText)
                .lineLimit(1)
                .padding(.top, 16)

            SpaceMetricBadgeGrid(
                tasks: "\(card.activeProgressSegments + 1)",
                docs: "\(card.activeProgressSegments + 2)",
                commands: "\((card.activeProgressSegments + 1) * 4)",
                artifacts: "\(max(card.activeProgressSegments, 1))",
                harness: card.primaryAction.harnessTitle,
                status: card.status
            )
            .padding(.top, 14)

            Spacer(minLength: 14)

            HStack(spacing: 10) {
                SpaceCardAction(title: "Open", systemImage: "folder", isAccented: card.isSelected)
                SpaceCardAction(title: card.primaryAction.title, systemImage: card.primaryAction.systemImage)

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SpacePalette.primaryText)
                    .frame(width: 40, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SpacePalette.button)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(SpacePalette.controlBorder, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(SpacePalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(card.isSelected ? SpacePalette.selectedBorder : SpacePalette.cardBorder, lineWidth: card.isSelected ? 1.4 : 1)
        )
    }
}

struct SpaceCardsHeader: View {
    let filters: [SpaceFilterData]

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    heading
                    Spacer(minLength: 32)
                }

                VStack(alignment: .leading, spacing: 16) {
                    heading
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active Spaces")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(SpacePalette.primaryText)

            Text("8 deployed across 3 spaces")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(SpacePalette.secondaryText)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct SpaceCards: View {
    let cards: [SpaceCardData]
    let filters: [SpaceFilterData]

    init(cards: [SpaceCardData] = SpaceCardData.mockCards, filters: [SpaceFilterData] = SpaceFilterData.mockFilters) {
        self.cards = cards
        self.filters = filters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SpaceCardsHeader(filters: filters)


        }
        .padding(24)
        .background(SpacePalette.canvas)
        .preferredColorScheme(.dark)
    }
}

struct SpaceAddButton: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))

            Text("Add Space")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(SpacePalette.primaryText)
        .frame(width: 180, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(SpacePalette.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(SpacePalette.controlBorder, lineWidth: 1)
        )
    }
}

struct SpaceDetailHeaderAction: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))

            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(SpacePalette.primaryText)
    }
}

struct SpaceDetailHeader: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Content Production")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SpacePalette.primaryText)

                Text("Research, drafting, and publishing workflows for a knowledge business.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SpacePalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            let ws = Workspace(.init(Workspace.self))
            let model = EditorModel(Session(ws.ref))

            SpaceBadges(model: model)
                .frame(maxWidth: .infinity, alignment: .trailing)

            //                HStack(spacing: 0) {
            //                    SpaceDetailHeaderAction(title: "Pause", systemImage: "pause.fill")
            //                    Spacer()
            //                    SpaceDetailHeaderAction(title: "Add task", systemImage: "plus")
            //                }

        }
        .frame(maxWidth: .infinity, alignment: .center)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(SpacePalette.secondaryText)
    }
}

struct SpaceDetailContent: View {
    let contents: [SpaceDetailContentData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(contents) { content in
                    SpaceDetailContentItem(content: content)
                    if content.id != contents.last?.id {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SpacePalette.secondaryText)
                    .frame(width: 30, height: 78)
                    .background(SpacePalette.canvas.opacity(0.97))
            }
        }
    }
}

struct SpaceDetailContentItem: View {
    let content: SpaceDetailContentData

    var body: some View {
        VStack(spacing: 8) {
            contentIcon
            Text(content.title)
                .padding(.top, 2)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(SpacePalette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 118, height: 36, alignment: .top)
        }
        .frame(width: 118)
        .opacity(content.isDimmed ? 0.28 : 1)
    }

    @ViewBuilder
    private var contentIcon: some View {
        switch content.kind {
            case .grouped:
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(SpacePalette.iconTile)
                    .frame(width: 76, height: 74)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                            Image(systemName: "doc.text.fill")
                        }
                            .font(.system(size: 21, weight: .regular))
                            .foregroundStyle(SpacePalette.iconAccent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(SpacePalette.iconBorder, lineWidth: 1)
                    )
            case .document:
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 61, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpacePalette.document)
                    .frame(width: 76, height: 74)
        }
    }
}

struct TranscriptRunHeader: View {
    let run: TranscriptRunData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: run.disclosureSystemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SpacePalette.tertiaryText)
                .frame(width: 14)

            Text(run.timestamp)
                .foregroundStyle(SpacePalette.tertiaryText)

            Text(run.duration)
                .foregroundStyle(SpacePalette.tertiaryText)
        }
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(SpacePalette.secondaryText)
    }
}

struct TranscriptRun: View {
    let run: TranscriptRunData

    var body: some View {
        VStack(alignment: .leading) {
            TranscriptInput(text: run.input)
                .padding(.bottom, 4)

            TranscriptTimeline(steps: run.steps)
                .padding(.bottom, 4)

            if let finalResponse = run.finalResponse {
                SpaceFinalResponse(response: finalResponse, links: run.responseLinks)
            }
        }
    }
}

struct SpaceTranscripts: View {
    let runs: [TranscriptRunData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(runs.enumerated()), id: \.element.id) { entry in
                TranscriptRun(run: entry.element)
                    .padding(.top, entry.offset == 0 ? 12 : 14)
            }
        }
    }
}

struct TranscriptInput: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(SpacePalette.primaryText)
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.leading, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(SpacePalette.cardBorder.opacity(0.33))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(SpacePalette.controlBorder, lineWidth: 0.45)
        )
    }
}

struct TranscriptStepRow: View {
    let step: TranscriptStepData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: step.systemImage)
                .frame(maxWidth: 26, maxHeight: 26, alignment: .center)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(SpacePalette.secondaryText)

            Text(step.detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(SpacePalette.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .padding(.leading, 8)
    }
}

struct TranscriptTimeline: View {
    let steps: [TranscriptStepData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps) { step in
                TranscriptStepRow(step: step)
            }
        }
    }
}

struct SpaceFinalResponse: View {
    let response: String
    let links: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.rectangle.stack.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(SpacePalette.iconAccent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(SpacePalette.selectedControl)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed Space run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SpacePalette.primaryText)

                    Text("12 actions, 2 artifacts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpacePalette.iconAccent)
                }
            }
            .padding(16)

            Rectangle()
                .fill(SpacePalette.controlBorder)
                .frame(height: 0.45)

            VStack(alignment: .leading, spacing: 12) {
                Text(response)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SpacePalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Change summary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SpacePalette.primaryText)

                VStack(alignment: .leading, spacing: 4) {
                    SpaceChangeSummaryRow(systemImage: "pencil", title: "Updated", detail: "Voice & Evidence Rules")
                    SpaceChangeSummaryRow(systemImage: "checkmark.circle", title: "Validated", detail: "24 evidence checks")
                    SpaceChangeSummaryRow(systemImage: "calendar", title: "Scheduled", detail: "Publishing run tomorrow at 9:00 AM")
                }

                //                if !links.isEmpty {
                //                    Rectangle()
                //                        .fill(SpacePalette.cardBorder)
                //                        .frame(height: 1)

                //                    VStack(alignment: .leading) {
                //                        ForEach(links, id: \.self) { link in
                //                            HStack(spacing: 9) {
                //                                Image(systemName: "doc.badge.checkmark")
                //                                    .font(.system(size: 14, weight: .medium))
                //                                    .foregroundStyle(SpacePalette.iconAccent)
                //
                //                                Text(link)
                //                                    .font(.system(size: 12, weight: .medium))
                //                                    .foregroundStyle(SpacePalette.primaryText)
                //
                //                                Spacer(minLength: 0)
                //
                //                                Text("Output")
                //                                    .font(.system(size: 10, weight: .medium))
                //                                    .foregroundStyle(SpacePalette.tertiaryText)
                //                            }
                //                        }
                //                    }
                //                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(SpacePalette.cardBorder.opacity(0.33))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(SpacePalette.controlBorder, lineWidth: 0.45)
        )
    }
}

struct SpaceMetricBadgeGrid: View {
    let tasks: String
    let docs: String
    let commands: String
    let artifacts: String
    let harness: String
    let status: SpaceStatus

    var body: some View {
        HStack {
            SpaceMetricBadge(title: "Tasks", value: tasks, systemImage: "checklist", tint: SpacePalette.accent)
            SpaceMetricBadge(title: "Docs", value: docs, systemImage: "doc.text", tint: SpacePalette.ready)
            SpaceMetricBadge(title: "Commands", value: commands, systemImage: "terminal", tint: SpacePalette.waiting)
            SpaceMetricBadge(title: "Artifacts", value: artifacts, systemImage: "shippingbox", tint: SpacePalette.scheduled)
            SpaceMetricBadge(title: "Harness", value: harness, systemImage: "cpu", tint: SpacePalette.iconAccent)
            SpaceMetricBadge(title: "Status", value: status.title, systemImage: "circle.fill", tint: status.tint)
        }
    }
}

struct SpaceMetricBadge: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SpacePalette.primaryText)
                .foregroundStyle(tint)
                .padding(.trailing, 4)

            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SpacePalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 42)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(SpacePalette.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .glassEffect(.regular.tint(SpacePalette.control), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SpaceContextPanel: View {
    let contents: [SpaceDetailContentData]
    let runs: [TranscriptRunData]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Context")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SpacePalette.secondaryText)

            VStack(alignment: .leading, spacing: 9) {
                if let run = runs.first {
                    SpaceContextFileRow(
                        title: "\(run.id) \(run.state.title.lowercased())",
                        detail: "\(run.actionCount) actions  ·  \(run.duration)",
                        systemImage: run.state.contextSystemImage,
                        tint: run.state.tint
                    )
                }
            }

            Rectangle()
                .fill(SpacePalette.cardBorder)
                .frame(height: 0.45)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Outputs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpacePalette.secondaryText)

                    Spacer(minLength: 0)

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpacePalette.tertiaryText)
                }

                if let links = runs.first?.responseLinks, !links.isEmpty {
                    ForEach(links, id: \.self) { link in
                        SpaceContextFileRow(title: link, detail: "Generated output", systemImage: "doc.badge.checkmark", tint: SpacePalette.scheduled)
                    }
                } else {
                    Text("No generated outputs")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SpacePalette.tertiaryText)
                }
            }

            Rectangle()
                .fill(SpacePalette.cardBorder)
                .frame(height: 0.45)

            VStack(alignment: .leading) {
                HStack {
                    Text("Sources")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpacePalette.secondaryText)

                    Spacer(minLength: 0)

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpacePalette.secondaryText)
                }

                ForEach(Array(contents.prefix(3))) { content in
                    SpaceContextSourceRow(content: content)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(SpacePalette.cardBorder.opacity(0.33))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(SpacePalette.controlBorder, lineWidth: 0.45)
        )
    }
}

struct SpaceContextFileRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SpacePalette.primaryText)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(SpacePalette.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
    }
}

struct SpaceContextSourceRow: View {
    let content: SpaceDetailContentData

    private var title: String {
        content.title.split(separator: "\n").joined(separator: " ")
    }

    var body: some View {
        switch content.kind {
            case .grouped:
                SpaceContextFileRow(title: title, detail: "Space source", systemImage: "square.stack.3d.up", tint: SpacePalette.iconAccent)
            case .document:
                SpaceContextFileRow(title: title, detail: "Document source", systemImage: "doc.text", tint: SpacePalette.ready)
        }
    }
}

struct SpaceChangeSummaryRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SpacePalette.iconAccent)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SpacePalette.secondaryText)
                .frame(width: 66, alignment: .leading)

            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(SpacePalette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

struct SpaceCanvas: View {
    let contents: [SpaceDetailContentData]
    let runs: [TranscriptRunData]

    init(
        contents: [SpaceDetailContentData] = SpaceDetailContentData.mockContents,
        runs: [TranscriptRunData] = TranscriptRunData.mockRuns) {
            self.contents = contents
            self.runs = runs
        }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 0) {
                SpaceDetailHeader()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 24)

                HStack(alignment: .top, spacing: 0) {
                    SpaceTranscripts(runs: runs)
                        .frame(width: 600, alignment: .topLeading)

                    Spacer()

                    SpaceContextPanel(contents: contents, runs: runs)
                        .frame(width: 310, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
        }
        .background(SpacePalette.canvas)
        .preferredColorScheme(.dark)
    }
}

private enum SpacePalette {
    static let canvas = Color(red: 0.084, green: 0.084, blue: 0.084)
    static let card = Color(red: 0.0942, green: 0.0948, blue: 0.0945)
    static let control = Color(red: 0.0848, green: 0.102, blue: 0.101)
    static let button = Color(red: 0.126, green: 0.132, blue: 0.129)
    static let shortcut = Color(red: 0.135, green: 0.139, blue: 0.138)
    static let selectedControl = Color(red: 0.175, green: 0.135, blue: 0.174)
    static let iconTile = Color(red: 0.205, green: 0.168, blue: 0.196)
    static let document = Color.white.opacity(0.86)
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.45)
    static let cardBorder = Color.white.opacity(0.09)
    static let controlBorder = Color.white.opacity(0.11)
    static let selectedBorder = Color(red: 0.76, green: 0.43, blue: 0.73)
    static let iconBorder = Color(red: 0.58, green: 0.36, blue: 0.54)
    static let iconAccent = Color(red: 0.91, green: 0.68, blue: 0.89)
    static let accent = Color(red: 0.79, green: 0.51, blue: 0.77)
    static let running = Color(red: 0.25, green: 0.76, blue: 0.39)
    static let waiting = Color(red: 1.00, green: 0.60, blue: 0.08)
    static let ready = Color(red: 0.34, green: 0.60, blue: 1.00)
    static let scheduled = Color(red: 0.57, green: 0.34, blue: 0.89)
    static let paused = Color.white.opacity(0.58)
    static let progressTrack = Color.white.opacity(0.14)
}

enum TranscriptRunState {
    case completed
    case blocked

    var title: String {
        switch self {
            case .completed:
                return "Completed"
            case .blocked:
                return "Blocked"
        }
    }

    var tint: Color {
        switch self {
            case .completed:
                return SpacePalette.running
            case .blocked:
                return SpacePalette.waiting
        }
    }

    var contextSystemImage: String {
        switch self {
            case .completed:
                return "checkmark.circle.fill"
            case .blocked:
                return "exclamationmark.circle.fill"
        }
    }
}

enum SpaceDetailContentKind {
    case grouped
    case document
}

enum SpaceStatus {
    case running
    case waiting
    case ready

    var title: String {
        switch self {
            case .running:
                return "Running"
            case .waiting:
                return "Waiting"
            case .ready:
                return "Ready"
        }
    }

    var tint: Color {
        switch self {
            case .running:
                return SpacePalette.running
            case .waiting:
                return SpacePalette.waiting
            case .ready:
                return SpacePalette.ready
        }
    }
}

enum SpacePrimaryAction {
    case pause
    case run

    var title: String {
        switch self {
            case .pause:
                return "Pause"
            case .run:
                return "Run"
        }
    }

    var systemImage: String {
        switch self {
            case .pause:
                return "pause.fill"
            case .run:
                return "play.fill"
        }
    }

    var harnessTitle: String {
        switch self {
            case .pause:
                return "Editorial"
            case .run:
                return "Support"
        }
    }
}

struct SpaceFilterData: Identifiable {
    let id: String
    let title: String
    let count: String
    let tint: Color
    let systemImage: String?
    let isSelected: Bool

    static let mockFilters = [
        SpaceFilterData(id: "all", title: "All", count: "8", tint: SpacePalette.accent, systemImage: "circle.hexagongrid.fill", isSelected: true),
        SpaceFilterData(id: "running", title: "Running", count: "3", tint: SpacePalette.running, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "attention", title: "Needs attention", count: "2", tint: SpacePalette.waiting, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "ready", title: "Ready", count: "2", tint: SpacePalette.ready, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "scheduled", title: "Scheduled", count: "1", tint: SpacePalette.scheduled, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "paused", title: "Paused", count: "0", tint: SpacePalette.paused, systemImage: nil, isSelected: false)
    ]
}

struct SpaceCardData: Identifiable {
    let id: String
    let title: String
    let status: SpaceStatus
    let summary: String
    let activity: String
    let metadata: String
    let activeProgressSegments: Int
    let progressTint: Color
    let primaryAction: SpacePrimaryAction
    let isSelected: Bool
    let iconLabels: [String]

    static let mockCards = [
        SpaceCardData(
            id: "content-production",
            title: "Content Production",
            status: .running,
            summary: "Drafting Voice & Evidence Rules",
            activity: "3 active  ·  1 blocked",
            metadata: "4 docs  ·  2 spaces  ·  1 harness",
            activeProgressSegments: 2,
            progressTint: SpacePalette.accent,
            primaryAction: .pause,
            isSelected: true,
            iconLabels: ["Research Desk", "Editorial Calendar", "Editorial System Charter", "Voice and Evidence Rules", "Publishing Cadence"]
        ),
        SpaceCardData(
            id: "client-intake",
            title: "Client Intake",
            status: .running,
            summary: "Reviewing intake brief",
            activity: "2 active  ·  0 blocked",
            metadata: "3 docs  ·  1 space  ·  1 harness",
            activeProgressSegments: 2,
            progressTint: SpacePalette.accent,
            primaryAction: .pause,
            isSelected: false,
            iconLabels: ["Intake Forms", "Intake Brief", "Qualification Checklist", "Internal Notes", "Client History"]
        ),
        SpaceCardData(
            id: "release-notes",
            title: "Release Notes",
            status: .waiting,
            summary: "Waiting on legal review",
            activity: "2 active  ·  1 blocked",
            metadata: "2 docs  ·  1 space  ·  1 harness",
            activeProgressSegments: 1,
            progressTint: SpacePalette.waiting,
            primaryAction: .pause,
            isSelected: false,
            iconLabels: ["Draft Notes", "Change Log Template", "Legal Review Brief", "Brand Guidelines", "Release Archive"]
        ),
        SpaceCardData(
            id: "competitive-research",
            title: "Competitive Research",
            status: .running,
            summary: "Collecting competitor updates",
            activity: "4 active  ·  1 blocked",
            metadata: "5 docs  ·  2 spaces  ·  1 harness",
            activeProgressSegments: 2,
            progressTint: SpacePalette.accent,
            primaryAction: .pause,
            isSelected: false,
            iconLabels: ["Market Pulse", "Competitor Matrix", "SWOT Analysis", "Research Sources", "Insight Report"]
        ),
        SpaceCardData(
            id: "support-triage",
            title: "Support Triage",
            status: .ready,
            summary: "Ready to send next issue",
            activity: "0 active  ·  0 blocked",
            metadata: "2 docs  ·  1 space  ·  1 harness",
            activeProgressSegments: 0,
            progressTint: SpacePalette.accent,
            primaryAction: .run,
            isSelected: false,
            iconLabels: ["Triage Queue", "Response Playbook", "Escalation Guide", "Resolution Log", "Knowledge Base"]
        ),
        SpaceCardData(
            id: "newsletter-ops",
            title: "Newsletter Ops",
            status: .running,
            summary: "Composing August issue",
            activity: "3 active  ·  0 blocked",
            metadata: "2 docs  ·  1 space  ·  1 harness",
            activeProgressSegments: 2,
            progressTint: SpacePalette.accent,
            primaryAction: .pause,
            isSelected: false,
            iconLabels: ["Issue Planner", "Template Library", "Subscriber Data", "Past Issues", "Send Checklist"]
        )
    ]
}

struct SpaceDetailContentData: Identifiable {
    let id: String
    let title: String
    let kind: SpaceDetailContentKind
    let isDimmed: Bool

    static let mockContents = [
        SpaceDetailContentData(id: "research-desk", title: "Research\nDesk", kind: .grouped, isDimmed: false),
        SpaceDetailContentData(id: "editorial-calendar", title: "Editorial\nCalendar", kind: .grouped, isDimmed: false),
        SpaceDetailContentData(id: "editorial-system-charter", title: "Editorial\nSystem Charter", kind: .document, isDimmed: false),
        SpaceDetailContentData(id: "voice-evidence", title: "Voice &\nEvidence Rules", kind: .document, isDimmed: false),
        SpaceDetailContentData(id: "publishing-cadence", title: "Publishing\nCadence", kind: .document, isDimmed: false),
        SpaceDetailContentData(id: "draft-notes", title: "Draft\nNotes", kind: .document, isDimmed: true)
    ]
}

struct TranscriptStepData: Identifiable {
    let id: String
    let systemImage: String
    let title: String
    let duration: String
    let detail: String
    let trailingSystemImages: [String]
}

struct TranscriptRunData: Identifiable {
    let id: String
    let disclosureSystemImage: String
    let state: TranscriptRunState
    let timestamp: String
    let duration: String
    let actionCount: Int
    let input: String
    let steps: [TranscriptStepData]
    let hiddenActionCount: Int?
    let finalResponse: String?
    let responseLinks: [String]
    let blockedMessage: String?

    static let mockRuns = [
        TranscriptRunData(
            id: "Run 184",
            disclosureSystemImage: "chevron.down",
            state: .completed,
            timestamp: "Today at 8:37 AM",
            duration: "6m 24s",
            actionCount: 12,
            input: "Review the latest research, update Voice & Evidence Rules, and prepare the next publishing run.",
            steps: [
                TranscriptStepData(id: "184-search", systemImage: "magnifyingglass", title: "Search", duration: "1m 02s", detail: "Searched Research Desk", trailingSystemImages: ["square.stack.3d.up.fill"]),
                TranscriptStepData(id: "184-read", systemImage: "doc.text", title: "Read", duration: "48s", detail: "Read Editorial System Charter", trailingSystemImages: ["square.stack.3d.up.fill"]),
                TranscriptStepData(id: "184-edit", systemImage: "pencil", title: "Edit", duration: "1m 16s", detail: "Updated Voice & Evidence Rules", trailingSystemImages: ["doc.text.fill"]),
                TranscriptStepData(id: "184-validate", systemImage: "checkmark.circle", title: "Validate", duration: "1m 05s", detail: "Ran evidence validation", trailingSystemImages: ["checkmark.circle.fill"]),
                TranscriptStepData(id: "184-schedule", systemImage: "calendar", title: "Schedule", duration: "47s", detail: "Scheduled Publishing Cadenc", trailingSystemImages: []),
                TranscriptStepData(id: "184-write", systemImage: "doc.text", title: "Write", duration: "53s", detail: "Created artifacts", trailingSystemImages: ["doc.text.fill", "doc.text.fill"])
            ],
            hiddenActionCount: 6,
            finalResponse: "Updated the evidence rules from the latest research, validated all 24 checks, and scheduled the publishing run for tomorrow at 9:00 AM.",
            responseLinks: ["Open Change Log", "Open Run Report"],
            blockedMessage: nil
        )
    ]
}

struct ContentProductionCanvasViewPreviews: PreviewProvider {
    static var previews: some View {
        SpaceCanvas()
            .frame(width: 1260, height: 800)
            .background(SpacePalette.canvas)
    }
}

//struct SpaceCardsPreviews: PreviewProvider {
//    static var previews: some View {
//        ScrollView {
//            SpaceCards()
//        }
//        .frame(width: 1000, height: 800)
//        .background(SpacePalette.canvas)
//    }
//}


