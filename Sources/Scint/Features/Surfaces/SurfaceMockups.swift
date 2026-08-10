import SwiftUI


enum TranscriptRunState {
    case completed
    case blocked

    var title: String {
        switch self {
            case .completed: "Completed"
            case .blocked: "Blocked"
        }
    }

    var tint: Color {
        switch self {
            case .completed: Design.Tint.running
            case .blocked: Design.Tint.blocked
        }
    }

    var contextSystemImage: String {
        switch self {
            case .completed: "checkmark.circle.fill"
            case .blocked: "exclamationmark.circle.fill"
        }
    }
}

enum SpaceDetailContentKind { case grouped, document }
enum SpaceStatus { case running, waiting, ready }

struct SpaceAddButton: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
            Text("Add Space")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(Design.Foreground.primary)
        .frame(width: 180, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Design.Tint.command)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Design.Border.controlBorder, lineWidth: 1)
        )
    }
}

struct SpaceCardAction: View {
    let title: String
    let systemImage: String
    var isAccented = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isAccented ? Design.Foreground.accent : Design.Foreground.primary)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Foreground.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAccented ? Design.Tint.command : Design.Foreground.secondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Design.Border.controlBorder, lineWidth: 1)
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
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)

                Spacer(minLength: 12)
            }

            Text(card.summary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Design.Foreground.secondary)
                .lineLimit(1)
                .padding(.top, 16)

            Spacer(minLength: 14)

            HStack(spacing: 10) {
                SpaceCardAction(title: "Open", systemImage: "folder", isAccented: card.isSelected)
                SpaceCardAction(title: card.title, systemImage: "app")

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Design.Foreground.primary)
                    .frame(width: 40, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Design.Background.raised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Design.Border.controlBorder, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Design.Background.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    card.isSelected ? Design.Border.controlBorder : Design.Border.cardBorder,
                    lineWidth: card.isSelected ? 1.4 : 1
                )
        )
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
        VStack(alignment: .leading, spacing: 22) { SpaceCardsHeader(filters: filters) }
            .padding(24)
            .background(Design.Background.canvas)
            .preferredColorScheme(.dark)
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
                .foregroundStyle(Design.Foreground.primary)

            Text("8 deployed across 3 spaces")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Design.Foreground.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct TranscriptRunHeader: View {
    let run: TranscriptRunData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: run.disclosureSystemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Foreground.tertiary)
                .frame(width: 14)

            Text(run.timestamp)
                .foregroundStyle(Design.Foreground.tertiary)

            Text(run.duration)
                .foregroundStyle(Design.Foreground.tertiary)
        }
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(Design.Foreground.secondary)
    }
}

struct TranscriptSurface: View {
    let run: TranscriptRunData

    var body: some View {
        VStack(alignment: .leading) {
            TranscriptInput(text: run.input)
                .padding(.bottom, 4)

            if let finalResponse = run.finalResponse {
                SpaceFinalResponse(response: finalResponse, links: run.responseLinks)
            }
        }
    }
}

struct TranscriptStepRow: View {
    let step: TranscriptStepData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: step.systemImage)
                .frame(maxWidth: 26, maxHeight: 26, alignment: .center)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Design.Foreground.secondary)

            Text(step.detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Design.Foreground.secondary)
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .padding(.leading, 8)
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
                    .foregroundStyle(Design.Foreground.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Design.Foreground.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed Space run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary)

                    Text("12 actions, 2 artifacts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Design.Foreground.accent)
                }
            }
            .padding(16)

            Rectangle()
                .fill(Design.Border.controlBorder)
                .frame(height: 0.45)

            VStack(alignment: .leading, spacing: 12) {
                Text(response)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Design.Foreground.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Change summary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)

                VStack(alignment: .leading, spacing: 4) {
                    SpaceChangeSummaryRow(systemImage: "pencil", title: "Updated", detail: "Voice & Evidence Rules")
                    SpaceChangeSummaryRow(systemImage: "checkmark.circle", title: "Validated", detail: "24 evidence checks")
                    SpaceChangeSummaryRow(systemImage: "calendar", title: "Scheduled", detail: "Publishing run tomorrow at 9:00 AM")
                }

                if !links.isEmpty {
                    Rectangle()
                        .fill(Design.Border.cardBorder)
                        .frame(height: 1)

                    VStack(alignment: .leading) {
                        ForEach(links, id: \.self) { link in
                            HStack(spacing: 9) {
                                Image(systemName: "doc.badge.checkmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Design.Foreground.accent)

                                Text(link)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Design.Foreground.primary)

                                Spacer(minLength: 0)

                                Text("Output")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Design.Foreground.tertiary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Design.Border.cardBorder.opacity(0.33))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Design.Border.controlBorder, lineWidth: 0.45)
        )
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
                .foregroundStyle(Design.Foreground.accent)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Design.Foreground.secondary)
                .frame(width: 66, alignment: .leading)

            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Design.Foreground.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

struct SpaceContent: Surface {
    var ref: Reference? = nil
    var host: any Host
    var model: any Model

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                let surface = AnySurface(host: host, model: model)
                let parameters = if let ref { SpaceGrid.content(ref) } else { host.parameters(model) }
                surface.render(surface, parameters, host.controls(model))
                    .scrollDisabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 144)
    }
}

struct ContentProductionCanvasViewPreviews: PreviewProvider {
    static var previews: some View {
        let run = TranscriptRunData.mockRuns[0]
        TranscriptSurface(run: run)
            .frame(width: 960, height: 800)
            .background(Design.Background.canvas)
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
        SpaceFilterData(id: "all", title: "All", count: "8", tint: Design.Foreground.accent, systemImage: "circle.hexagongrid.fill", isSelected: true),
        SpaceFilterData(id: "running", title: "Running", count: "3", tint: Design.Tint.running, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "attention", title: "Needs attention", count: "2", tint: Design.Tint.blocked, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "ready", title: "Ready", count: "2", tint: Design.Tint.active, systemImage: nil, isSelected: false),
        SpaceFilterData(id: "scheduled",title: "Scheduled",count: "1",tint: Design.Tint.observe,systemImage: nil,isSelected: false),
        SpaceFilterData(id: "paused", title: "Paused", count: "0", tint: Design.Tint.inactive, systemImage: nil, isSelected: false)
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
                TranscriptStepData(id: "184-schedule", systemImage: "calendar", title: "Schedule", duration: "47s", detail: "Scheduled Publishing Cadence", trailingSystemImages: []),
                TranscriptStepData(id: "184-write", systemImage: "doc.text", title: "Write", duration: "53s", detail: "Created artifacts", trailingSystemImages: ["doc.text.fill", "doc.text.fill"])
            ],
            hiddenActionCount: 6,
            finalResponse: "Updated the evidence rules from the latest research, validated all 24 checks, and scheduled the publishing run for tomorrow at 9:00 AM.",
            responseLinks: ["Open Change Log", "Open Run Report"],
            blockedMessage: nil
        )
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

    enum SpacePrimaryAction { case pause, run }

    static let mockCards = [
        SpaceCardData(
            id: "content-production",
            title: "Content Production",
            status: .running,
            summary: "Drafting Voice & Evidence Rules",
            activity: "3 active  ·  1 blocked",
            metadata: "4 docs  ·  2 spaces  ·  1 harness",
            activeProgressSegments: 2,
            progressTint: Design.Foreground.accent,
            primaryAction: SpacePrimaryAction.pause,
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
            progressTint: Design.Foreground.accent,
            primaryAction: SpacePrimaryAction.pause,
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
            progressTint: Design.Tint.observe,
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
            progressTint: Design.Foreground.accent,
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
            progressTint: Design.Foreground.accent,
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
            progressTint: Design.Foreground.accent,
            primaryAction: .pause,
            isSelected: false,
            iconLabels: ["Issue Planner", "Template Library", "Subscriber Data", "Past Issues", "Send Checklist"]
        )
    ]
}
