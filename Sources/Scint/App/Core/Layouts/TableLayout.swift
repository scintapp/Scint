//import SwiftUI
//import ScintRuntime
//import ScintComponents
//
//
//struct TableHeader: View {
//    var name: String
//    var expanded: Bool
//    var onToggle: () -> Void
//
//    var body: some View {
//        Button(action: onToggle) {
//            HStack {
//                Text(name)
//                    .font(Typography.body.weight(.semibold))
//                    .foregroundStyle(Style.Foreground.secondary)
//
//                Spacer()
//
//                Image(systemName: "chevron.down")
//                    .font(Typography.footnote.weight(.heavy))
//                    .foregroundStyle(Style.Foreground.secondary)
//                    .rotationEffect(.degrees(expanded ? .zero : -90))
//                    .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
//                    .background(Circle().fill(Style.Background.surface))
//            }
//            .contentShape(Rectangle())
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//struct TableRow: View {
//    @State private var hovered = false
//    var intent: Intent
//    var transcript: Reference?
//    var enabled: Bool
//    var model: any Model
//
//    var body: some View {
//        let icon = Iconography.icon(for: intent)
//        let selected = transcript != nil && model.session.transcript == transcript
//
//        Button { if let transcript { model.select(transcript) } } label: {
//            HStack(spacing: Style.Spacing.icon) {
//                Iconography.Icon(
//                    symbol: icon.symbol,
//                    tint: icon.tint,
//                    sizing: Metrics.rowIcon,
//                    selected: enabled
//                )
//                .frame(width: Metrics.rowIcon, height: Metrics.rowIcon)
//
//                Text(intent.forms.label)
//                    .font(Typography.body)
//                    .foregroundStyle(enabled ? Style.Foreground.primary : Style.Foreground.secondary)
//                    .lineLimit(1)
//
//                Spacer(minLength: .zero)
//            }
//            .padding(.horizontal, 8)
//            .frame(height: Style.Dimension.control(.regular))
//            .background(
//                Style.Shape.card.fill(
//                    selected || hovered ? Style.Background.surface : .clear
//                )
//            )
//            .contentShape(Style.Shape.card)
//        }
//        .buttonStyle(.plain)
//        .disabled(!enabled || transcript == nil)
//        .onHover { hovered = $0 }
//    }
//}
//
//struct TableCard<Rows: View>: View {
//    var model: any Model
//    var space: Reference
//    var transcript: Reference
//    var running: Bool
//    var expanded: Bool
//    var onToggle: () -> Void
//    @ViewBuilder var rows: Rows
//
//    var body: some View {
//        let harness = Space.with(space, { $0.harness }).flatMap { $0 }
//        let intent = harness.flatMap { Harness.with($0, { $0.intent }) }
//        let selected = model.session.transcript == transcript
//        let updated = Transcript.with(transcript) { $0.entries.last?.created ?? $0.started }
//            .flatMap { $0 } ?? transcript.descriptor.created
//
//        VStack(spacing: .zero) {
//            Button(action: onToggle) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(space.descriptor.name)
//                        .font(Typography.lead)
//                        .foregroundStyle(selected ? Style.Foreground.primary : Style.Foreground.secondary)
//                        .lineLimit(1)
//
//                    if running {
//                        Text(intent.map { "\($0.forms.running)…" } ?? "Working…")
//                            .font(Typography.detail)
//                            .foregroundStyle(Style.Foreground.secondary)
//                            .lineLimit(1)
//                    } else {
//                        HStack(spacing: 4) {
//                            Text(intent?.forms.completed ?? "Updated")
//                            Text("at")
//                            Text(updated, style: .time)
//                        }
//                        .font(Typography.detail)
//                        .foregroundStyle(Style.Foreground.secondary)
//                        .lineLimit(1)
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal, 8)
//                .padding(.vertical, 8)
//                .contentShape(Rectangle())
//            }
//            .buttonStyle(.plain)
//
//            if expanded {
//                VStack(spacing: 4) { rows }
//                    .padding(.horizontal, 8)
//                    .padding(.bottom, 2)
//            }
//        }
//        .background(Style.Shape.card.fill(selected ? Style.Background.surface : .clear))
//    }
//}
//
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
