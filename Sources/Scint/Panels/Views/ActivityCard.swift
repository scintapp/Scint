import SwiftUI


extension Harness.Intent {
    /// Every label form for one intent, resolved in a single switch so the tenses
    /// cannot drift apart.
    var forms: (label: String, running: String, completed: String) {
        switch self {
            case .compose: ("Compose", "Composing", "Composed")
            case .dispatch: ("Dispatch", "Dispatching", "Dispatched")
            case .observe: ("Observe", "Observing", "Observed")
            case .evaluate: ("Evaluate", "Evaluating", "Evaluated")
            case .search: ("Research", "Researching", "Researched")
        }
    }
}

/// One intent inside an activity card. An intent with no harness behind it still
/// appears, dimmed, so the group reads as a capability list rather than a history.
struct ActivityRow: View {
    @State private var hovered = false

    var intent: Harness.Intent
    var transcript: Reference?
    var enabled: Bool
    var model: any Model

    var body: some View {
        let icon = Iconography.icon(for: intent)
        let selected = transcript != nil && model.session.transcript == transcript

        Button { if let transcript { model.select(transcript) } } label: {
            HStack(spacing: Style.Spacing.lg) {
                Iconography.Icon(
                    symbol: icon.symbol,
                    tint: icon.tint,
                    sizing: Style.Spacing.xl,
                    selected: enabled
                )
                .frame(width: Style.Spacing.xl, height: Style.Spacing.xl)

                Text(intent.forms.label)
                    .font(Typography.cardRow)
                    .foregroundStyle(enabled ? Style.Foreground.base : Style.Foreground.faint)
                    .lineLimit(Style.Limit.singleLine)

                Spacer(minLength: .zero)
            }
            .padding(.horizontal, Style.Spacing.md)
            .frame(height: Style.Spacing.xxl + Style.Spacing.sm)
            .background(
                Style.Shape.small.fill(
                    selected || hovered ? Color.primary.opacity(Style.Opacity.hairline) : .clear
                )
            )
            .contentShape(Style.Shape.small)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || transcript == nil)
        .onHover { hovered = $0 }
    }
}

/// A space and its intents. The header names the space and what it last did or is doing
/// now; the intents sit enclosed beneath it. Disclosure is owned by the caller so the
/// card stays a view.
struct ActivityCard<Rows: View>: View {
    var space: Reference
    var transcript: Reference
    var running: Bool
    var model: any Model
    var expanded: Bool
    var onToggle: () -> Void
    @ViewBuilder var rows: Rows

    var body: some View {
        let harness = Space.with(space, { $0.harness }).flatMap { $0 }
        let intent = harness.flatMap { Harness.with($0, { $0.intent }) }
        let updated = Transcript.with(transcript) {
            $0.entries.last?.created ?? $0.started
        }.flatMap { $0 } ?? transcript.descriptor.created
        let selected = model.session.transcript == transcript

        VStack(spacing: .zero) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                    Text(space.descriptor.name)
                        .font(Typography.cardHeading)
                        .foregroundStyle(selected ? Style.Foreground.base : Style.Foreground.subtle)
                        .lineLimit(Style.Limit.singleLine)

                    if running {
                        Text(intent.map { "\($0.forms.running)…" } ?? "Working…")
                            .font(Typography.cardDetail())
                            .foregroundStyle(Style.Foreground.faint)
                            .lineLimit(Style.Limit.singleLine)
                    } else {
                        HStack(spacing: Style.Spacing.sm) {
                            Text(intent?.forms.completed ?? "Updated")
                            Text("at")
                            Text(updated, style: .time)
                        }
                        .font(Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.faint)
                        .lineLimit(Style.Limit.singleLine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Style.Spacing.lg)
                .padding(.vertical, Style.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: Style.Spacing.xs) { rows }
                    .padding(.horizontal, Style.Spacing.md)
                    .padding(.bottom, Style.Spacing.lg)
            }
        }
        .background(Style.Shape.medium.fill(Style.Background.group))
    }
}

/// A disclosure header for one activity group.
struct ActivityHeader: View {
    var name: String
    var expanded: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(name)
                    .font(Typography.cardRow.weight(.semibold))
                    .foregroundStyle(Style.Foreground.faint)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(Typography.label.weight(.heavy))
                    .foregroundStyle(Style.Foreground.muted)
                    .rotationEffect(.degrees(expanded ? .zero : -90))
                    .frame(width: Style.Spacing.xxl, height: Style.Spacing.xxl)
                    .background(Circle().fill(Style.Background.group))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
