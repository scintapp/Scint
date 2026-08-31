import SwiftUI


//struct TableRow: View {
//    let title: String
//    let description: String
//    let selected: Bool
//    let onSelect: () -> Void
//
//    var body: some View {
//        Button(action: onSelect) {
//            VStack(alignment: .leading, spacing: 5) {
//                Text(title)
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(Style.Foreground.base)
//                    .lineLimit(1)
//
//                if !description.isEmpty {
//                    Text(description)
//                        .font(.system(size: 11))
//                        .foregroundStyle(Style.Foreground.faint)
//                        .lineLimit(1)
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 9)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background {
//                RoundedRectangle(cornerRadius: 10, style: .continuous)
//                    .fill(selected ? Color.secondary.opacity(0.16) : Color.clear)
//            }
//            .contentShape(Rectangle())
//        }
//        .buttonStyle(.plain)
//    }
//}

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

struct ActivityCard<Rows: View>: View {
    var model: any Model
    var space: Reference
    var transcript: Reference
    var running: Bool
    var expanded: Bool
    var onToggle: () -> Void
    @ViewBuilder var rows: Rows

    var body: some View {
        let harness = Space.with(space, { $0.harness }).flatMap { $0 }
        let intent = harness.flatMap { Harness.with($0, { $0.intent }) }
        let selected = model.session.transcript == transcript
        let updated = Transcript.with(transcript) { $0.entries.last?.created ?? $0.started }
            .flatMap { $0 } ?? transcript.descriptor.created

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
                .padding(.horizontal, Style.Spacing.md)
                .padding(.vertical, Style.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: Style.Spacing.xs) { rows }
                    .padding(.horizontal, Style.Spacing.md)
                    .padding(.bottom, Style.Spacing.lg)
            }
        }
        .background(Style.Shape.medium.fill(selected ? Style.Background.group : .clear))
    }
}

//struct TableLayout<Content: View>: View {
//    @ViewBuilder let content: () -> Content
//
//    init(@ViewBuilder content: @escaping () -> Content) {
//        self.content = content
//    }
//
//    var body: some View {
//        LazyVStack(spacing: 2) { content() }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//    }
//}


extension Harness.Intent {
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
