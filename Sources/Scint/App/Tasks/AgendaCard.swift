import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaCard: View {
    let ref: Reference
    let model: any Model
    let sizing: CGFloat = 130
    let scale = 0.33

    @State var hovered: Bool

    var selected: Bool { model.session.selection.selected(ref) }
    var document: ScintRuntime.Document? { ScintRuntime.Document.with(ref, { $0 }) }
    var preview: [Block] { document?.blocks ?? [] }
    var title: String { document.flatMap(TaskHeader.task)?.text ?? "" }
    var done: Bool { document.flatMap(TaskHeader.task)?.done ?? false }
    var command: Reference? { document.flatMap { document in (Space.with(document.origin, { $0.interface }) ?? nil).flatMap { document.values($0)["command"]?.references.first } } }
    var space: Reference? { document.flatMap { document in (Space.with(document.origin, { $0.interface }) ?? nil).flatMap { document.values($0)["space"]?.references.first } } }

    var due: String? {
        guard let schedule = document.map(TaskHeader.schedule), let moment = schedule.moment else { return nil }
        let when = When(moment, repeats: schedule.repeats)
        let date = when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "Today, \(time)" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow, \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())), \(time)"
    }

    var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(2)

                Text(due ?? updated)
                    .font(.system(size: 11))
                    .foregroundStyle(Style.Foreground.muted)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: 0.5)

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(preview.prefix(9)) {
                        DocumentBlock(block: $0)
                            .allowsHitTesting(false)
                            .textSelection(.disabled)
                            .opacity(0.8)
                    }
                }
                .frame(width: proxy.size.width / scale, alignment: .topLeading)
                .textSelection(.disabled)
                .scaleEffect(scale, anchor: .topLeading)
            }
        }
        .padding(Style.Spacing.tile)
        .frame(minWidth: sizing, maxWidth: .infinity, minHeight: sizing * 1.2, maxHeight: sizing * 1.2, alignment: .top)
        .clipShape(Style.Shape.card)
        .background(Style.Shape.card.fill(Style.Background.surface.opacity(0.7)))
        .overlay(Style.Shape.card.strokeBorder(selected ? Style.Tint.document.dull : Style.Border.hairline))
        .contentShape(Style.Shape.card)
        .shadow(color: .black.opacity(0.3), radius: hovered ? 5 : 3, y: hovered ? 4 : 2)
        .offset(y: hovered || selected ? -3 : 0)
        .onHover { hover in withAnimation(Style.Motion.disclosure) { hovered = hover } }
        .onDrag { ReferenceTransfer.provider(for: ref) ?? NSItemProvider() }
    }
}




