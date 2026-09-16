import SwiftUI


struct ActivitySurface: Surface {
    var panel: any Panel
    var model: any Model
    var onOpen: () -> Void

    var context: Composition? { model.session.space.flatMap { model.compose($0) } }
    var active: Bool { context?.state == .working }

    var state: String {
        switch context?.state {
            case .active: "Active"
            case .working: "Working"
            case .inactive: "Inactive"
            case .completed: "Completed"
            case .failed: "Failed"
            default: ""
        }
    }

    var body: some View {
        let params = ActivitySummary.parameters(model)
        let controls = ActivitySummary.controls(model)

        if let transcript = params.ref {
            VStack(alignment: .leading, spacing: Style.Spacing.xxl) {
                HStack(alignment: .center, spacing: Style.Spacing.lg) {
                    HStack(spacing: Style.Spacing.lg) {
                        if active { RunningIndicator(size: .small) }

                    }
                    .frame(width: 120, alignment: .leading)

                    TranscriptPicker(model: model)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)

                    HStack(spacing: Style.Spacing.lg) {
                        if active {
                            Button("Stop") { controls.onAction?(.init(ref: model.session.space, name: "Stop")) }
                                .buttonStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(Style.Tint.accent.opacity(0.4))
                        }
                        Text(state)
                            .font(.system(size: 13))
                            .foregroundStyle(active ? Style.Tint.accent.opacity(0.4) : Style.Foreground.muted)
                    }
                    .frame(width: 120, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxHeight: 28, alignment: .top)

                VStack {
                    Button {
                        controls.onSelect?(.init(ref: transcript, name: ""))
                        onOpen()
                    } label: {
                        ForEach(params.sections.filter { $0.id != AnyHashable("activity") && !$0.items.isEmpty }) { section in
                            ForEach(section.items) { item in
                                if let ref = item.ref, let entryId = item.entryId {
                                    TranscriptEntry(transcript: ref, entryId: entryId, model: model)
                                        .lineLimit(Style.Limit.activityMessageLines)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(alignment: .top)
                .padding(.horizontal, 12)

                HStack(alignment: .bottom) {
                    ForEach(params.sections.filter { $0.id == AnyHashable("activity") && !$0.items.isEmpty }) { section in
                        HStack(alignment: .center, spacing: Style.Spacing.lg) {
                            ForEach(section.items) { item in
                                if let ref = item.ref, let entryId = item.entryId {
                                    TranscriptEntry(transcript: ref, entryId: entryId, model: model)
                                        .lineLimit(Style.Limit.singleLine)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 28, alignment: .bottom)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: 660, alignment: .leading)
            .background {
                Style.Shape.medium
                    .fill(Style.Background.card.opacity(0.5))
                    .glassEffect(.regular, in: Style.Shape.medium)
                    .blur(radius: 2)
                Style.Shape.medium
                    .fill(Style.Background.card.opacity(0.5))
            }
            .overlay {
                Style.Shape.medium
                    .stroke(Style.Border.card.opacity(0.75), lineWidth: 1, antialiased: true)
            }
            .clipShape(Style.Shape.medium)
        }
    }
}
