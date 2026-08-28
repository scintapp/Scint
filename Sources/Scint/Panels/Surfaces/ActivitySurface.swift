import SwiftUI


enum ActivityGroupKind {
    case working, recent, scheduled

    var title: String {
        switch self {
            case .working: "Working"
            case .recent: "Recent"
            case .scheduled: "Scheduled"
        }
    }
}

private extension Harness.Intent {
    var activityLabel: String {
        switch self {
            case .compose: "Compose"
            case .dispatch: "Dispatch"
            case .observe: "Observe"
            case .evaluate: "Evaluate"
            case .search: "Research"
        }
    }

    var runningLabel: String {
        switch self {
            case .compose: "Composing…"
            case .dispatch: "Dispatching…"
            case .observe: "Observing…"
            case .evaluate: "Evaluating…"
            case .search: "Researching…"
        }
    }

    var completedLabel: String {
        switch self {
            case .compose: "Composed"
            case .dispatch: "Dispatched"
            case .observe: "Observed"
            case .evaluate: "Evaluated"
            case .search: "Researched"
        }
    }

    var activityTint: Color {
        switch self {
            case .compose, .observe: Style.Foreground.faint
            case .dispatch: .orange
            case .evaluate: .pink
            case .search: .green
        }
    }
}

struct ActivityStatus: View {
    var state: Composition.State
    var labeled = true

    var body: some View {
        HStack(spacing: Style.Spacing.sm + 1) {
            Circle()
                .fill(state == .working ? Style.Tint.harness.opacity(Style.Opacity.muted) : .clear)
                .overlay {
                    Circle().strokeBorder(
                        state == .active
                        ? Style.Tint.harness.opacity(Style.Opacity.faint)
                        : state == .inactive
                        ? Style.Foreground.disabled
                        : .clear,
                        lineWidth: 1
                    )
                }
                .frame(width: 5, height: 5)

            if labeled {
                Text(state.label)
                    .font(Typography.label)
                    .foregroundStyle(Style.Foreground.faint)
                    .lineLimit(Style.Limit.singleLine)
            }
        }
        .help(state.label)
    }
}

struct ActivityRow: View {
    @State private var hovered = false

    var model: any Model
    var intent: Harness.Intent
    var transcript: Reference?
    var enabled: Bool
    var state: Composition.State

    var body: some View {
        let label = intent.activityLabel
        let selected = transcript == model.session.transcript

        HStack(spacing: Style.Spacing.md) {
            Button {
                if let transcript { model.select(transcript) }
            } label: {
                HStack(spacing: Style.Spacing.xl) {
                    Image(systemName: "square")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(intent.activityTint)
                        .frame(width: Style.Spacing.xl, height: Style.Spacing.xl)

                    Text(label)
                        .font(.system(size: 13, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Style.Foreground.subtle : Style.Foreground.muted)
                        .lineLimit(Style.Limit.singleLine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled || transcript == nil)

            Spacer(minLength: Style.Spacing.md)

            if hovered && enabled {
                HStack(spacing: Style.Spacing.sm) {
                    if let transcript {
                        Button { model.select(transcript) } label: {
                            Image(systemName: "arrow.right")
                                .frame(width: 20, height: 20)
                                .background(Style.Shape.small.fill(Style.Background.raised))
                                .contentShape(Style.Shape.small)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(label.lowercased()) transcript")
                    }
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Style.Foreground.faint)
                .transition(.opacity)
            } else if enabled {
                ActivityStatus(state: state, labeled: false)
            }
        }
        .padding(.leading, Style.Spacing.xl)
        .padding(.trailing, Style.Spacing.md)
        .frame(height: 28)
        .background(
            Style.Shape.small.fill(
                selected
                ? Color.primary.opacity(Style.Opacity.hairline)
                : hovered && enabled
                ? Color.primary.opacity(Style.Opacity.hairline)
                : .clear
            )
        )
        .contentShape(Style.Shape.small)
        .opacity(enabled ? Style.Opacity.full : Style.Opacity.faint)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: Style.Duration.menuSelection), value: hovered)
        .help(enabled ? transcript == nil ? "No \(label.lowercased()) transcript yet" : label : "No \(label.lowercased()) harness")
    }
}

struct ActivitySection: View {
    @State private var hovered = false

    var panel: any Panel
    var model: any Model
    var context: Composition

    var body: some View {
        let expanded = panel.state.isExpanded(context.space)
        let selected = model.session.origin == context.space
        let harnesses = context.harnesses
        let branches: [Reference] = Transcript.with(context.transcript) { root in
            root.entries.compactMap { entry in
                guard case .transcript(_, let transcript, _) = entry else { return nil }
                return transcript
            }
        } ?? []
        let current = Harness.with(context.harness, { $0.intent })

        VStack(spacing: .zero) {
            HStack(alignment: .center, spacing: Style.Spacing.md) {
                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        panel.state.setExpanded(context.space)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Style.Spacing.xs + 1) {
                        Text(context.space.descriptor.name)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(selected ? Style.Foreground.base : Style.Foreground.subtle)
                            .lineLimit(Style.Limit.singleLine)

                        Text(current?.runningLabel ?? "Working…")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Style.Foreground.faint)
                            .lineLimit(Style.Limit.singleLine)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: Style.Spacing.md)

                if hovered {
                    HStack(spacing: Style.Spacing.sm) {
                        Button { model.select(context.transcript) } label: {
                            Image(systemName: "arrow.right")
                                .frame(width: 22, height: 22)
                                .background(Style.Shape.small.fill(Style.Background.raised))
                                .contentShape(Style.Shape.small)
                        }
                        .buttonStyle(.plain)
                        .help("Open overview transcript")

                        Button {
                            if context.state == .inactive { let _ = model.start(context.space) }
                            else { let _ = Runtime.shared.stop(context.space) }
                        } label: {
                            Image(systemName: context.state == .inactive ? "play.fill" : "stop.fill")
                                .frame(width: 22, height: 22)
                                .background(Style.Shape.small.fill(Style.Background.raised))
                                .contentShape(Style.Shape.small)
                        }
                        .buttonStyle(.plain)
                        .help(context.state == .inactive ? "Start" : "Stop")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Style.Foreground.faint)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Style.Spacing.xl)
            .padding(.vertical, Style.Spacing.lg)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }

            if expanded {
                VStack(spacing: Style.Spacing.xs) {
                    ForEach(Array(Harness.Intent.allCases.enumerated()), id: \.offset) { _, intent in
                        let transcriptName = String(describing: intent).capitalized
                        let transcript = branches.first { $0.descriptor.name == transcriptName }
                        let enabled = harnesses.contains { harness in
                            Harness.with(harness) { $0.intent == intent } == true
                        }
                        let active = transcript.flatMap { branch in
                            Transcript.with(branch) { $0.active }
                        } == true

                        ActivityRow(
                            model: model,
                            intent: intent,
                            transcript: transcript,
                            enabled: enabled,
                            state: active ? context.state : .inactive
                        )
                    }
                }
                .padding(.horizontal, Style.Spacing.md)
                .padding(.bottom, Style.Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            Style.Shape.medium.fill(
                selected
                ? Style.Background.group.opacity(Style.Opacity.full)
                : Style.Background.group
            )
        )
        .overlay {
            Style.Shape.medium.strokeBorder(
                selected ? Style.Border.group : .clear,
                lineWidth: 0.5
            )
        }
        .animation(.easeOut(duration: Style.Duration.menuSelection), value: hovered)
    }
}

struct ActivityHistoryRow: View {
    @State private var hovered = false

    var kind: ActivityGroupKind
    var context: Composition
    var model: any Model

    var body: some View {
        let selected = model.session.transcript == context.transcript
        let intent = Harness.with(context.harness, { $0.intent })
        let updated = Transcript.with(context.transcript) {
            $0.entries.last?.created ?? $0.started ?? context.transcript.descriptor.created
        } ?? context.transcript.descriptor.created
        let detail = kind == .recent
            ? intent?.completedLabel ?? "Updated"
            : String(intent?.runningLabel.dropLast() ?? "Scheduled")

        Button { model.select(context.transcript) } label: {
            VStack(alignment: .leading, spacing: Style.Spacing.xs + 1) {
                Text(context.space.descriptor.name)
                    .font(.system(size: 15, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Style.Foreground.base : Style.Foreground.subtle)
                    .lineLimit(Style.Limit.singleLine)

                HStack(spacing: Style.Spacing.sm) {
                    Text(detail)
                    Text("at")
                    Text(updated, style: .time)
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Style.Foreground.faint)
                .lineLimit(Style.Limit.singleLine)
            }
            .padding(.horizontal, Style.Spacing.lg)
            .padding(.vertical, Style.Spacing.md + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Style.Shape.small.fill(
                    selected || hovered
                    ? Color.primary.opacity(Style.Opacity.hairline)
                    : .clear
                )
            )
            .contentShape(Style.Shape.small)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: Style.Duration.menuSelection), value: hovered)
    }
}

struct ActivityGroup: View {
    @State private var expanded = true

    var kind: ActivityGroupKind
    var contexts: [Composition]
    var panel: any Panel
    var model: any Model

    var body: some View {
        if !contexts.isEmpty {
            VStack(alignment: .leading, spacing: Style.Spacing.lg) {
                Button {
                    withAnimation(.smooth(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(kind.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Style.Foreground.faint)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Style.Foreground.muted)
                            .rotationEffect(.degrees(expanded ? .zero : -90))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Style.Background.group))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    LazyVStack(spacing: kind == .working ? Style.Spacing.lg : Style.Spacing.xs) {
                        ForEach(contexts, id: \.space) { context in
                            if kind == .working {
                                ActivitySection(panel: panel, model: model, context: context)
                            } else {
                                ActivityHistoryRow(kind: kind, context: context, model: model)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct ActivitySurface: Surface {
    var panel: any Panel
    var model: any Model

    var contexts: [Composition] {
        Runtime.shared.context().sorted {
            $0.transcript.descriptor.created > $1.transcript.descriptor.created
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Style.Spacing.xxxl) {
                ActivityGroup(
                    kind: .working,
                    contexts: contexts.filter { $0.state == .working },
                    panel: panel,
                    model: model
                )
                ActivityGroup(
                    kind: .recent,
                    contexts: contexts.filter { $0.state == .inactive },
                    panel: panel,
                    model: model
                )
                ActivityGroup(
                    kind: .scheduled,
                    contexts: contexts.filter { $0.state == .active },
                    panel: panel,
                    model: model
                )
            }
            .padding(.horizontal, Style.Spacing.lg)
            .padding(.vertical, Style.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
