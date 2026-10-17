import Foundation
import SwiftUI
@testable import ScintRuntime
@testable import Scint


@MainActor final class Harness: Model {
    var session: Session
    init(_ session: Session) { self.session = session }
}

@MainActor var failures = 0
@MainActor func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1 }
    print(condition ? "PASS" : "FAIL", "[\(line)]", message)
}

@main struct AgendaRegression {
    @MainActor static func main() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.date(byAdding: .day, value: offset, to: today)!)!
        }
        func label(_ date: Date) -> String { date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }

        let app = Space.new(from: .init(name: "Agenda App"))
        for name in ["Library", "Spaces", "Tasks"] { Space.new(from: .init(name: name, space: app)) }
        let model = Harness(Session(DataModel(app)))
        let agenda = model.session.agenda

        func task(_ name: String, _ moment: Date?, repeats: When.Repeat = .never, blocks: [Block] = []) -> Reference {
            let ref = ScintRuntime.Document.new(from: .init(name: name, origin: agenda, header: .task, blocks: blocks))
            if let moment { ScintRuntime.Document.update(ref) { TaskHeader.schedule(&$0, moment, repeats: repeats) } }
            return ref
        }
        func current(_ ref: Reference) -> (id: UUID, text: String, done: Bool)? { ScintRuntime.Document.with(ref, { TaskHeader.task($0) }) ?? nil }

        let morning = task("Morning", day(0, 11, 59), blocks: [.paragraph(UUID(), "Summary line"), .paragraph(UUID(), "Detail")])
        let noon = task("Noon", day(0, 12))
        _ = task("Evening", day(0, 17))
        _ = task("Daily", day(-3, 8), repeats: .daily)
        let midnight = task("Midnight", day(2))
        _ = task("Past", day(-2, 10))
        _ = task("Loose", nil)
        check(ScintRuntime.Document.with(midnight, { TaskHeader.schedule($0).moment }) == day(2), "the harness schedules tasks through the existing task header")

        let params = AgendaMapper.parameters(model)
        let controls = AgendaMapper.controls(model)
        check(params.tabbed && params.sections.map(\.name) == ["Today", "Upcoming", "Later", "All Tasks"], "the modes are declared as tabs in order")

        let declared = params.shown("today")
        let days = declared.first?.sections ?? []
        check(declared.map(\.layout) == [.row] && days.allSatisfy { $0.layout == .table }, "Today declares a row whose peers are day tables")
        check(days.compactMap { Value.formatter.date(from: $0.id.base as? String ?? "") } == (0..<5).map { day($0) }, "the row declares five consecutive days from today")
        check(days.first?.image == "circle.fill" && days.dropFirst().allSatisfy(\.image.isEmpty), "only today carries the marker")

        func rows(_ section: SectionParams) -> [String] {
            section.sections.flatMap { group in group.items.map { "\(group.name)/\($0.name)" } }
        }

        check(rows(days[0]) == ["Morning/Daily", "Morning/Morning", "Afternoon/Noon", "Later/Evening"], "today groups by hour with 12:00 and 17:00 opening the next group")
        check(rows(days[2]) == ["Morning/Midnight", "Morning/Daily"], "a task exactly at midnight stays on its day beside recurrences")
        check(rows(days[1]) == ["Morning/Daily"] && days[1].sections.map(\.name) == ["Morning"], "the previous day excludes the midnight task and omits empty groups")
        check(rows(params.shown("upcoming")[0]) == ["Tomorrow/Daily", "\(label(day(2)))/Midnight"], "Upcoming starts tomorrow with one occurrence per task")
        check(rows(params.shown("later")[0]) == ["Unscheduled/Loose"], "Later lists tasks without a date")
        check(rows(params.shown("all")[0]) == ["\(label(day(-2)))/Past", "Today/Daily", "Today/Morning", "Today/Noon", "Today/Evening", "\(label(day(2)))/Midnight", "Unscheduled/Loose"], "All Tasks lists every task by day, then the unscheduled ones")

        let state = StateContainer()
        let key: [AnyHashable] = ["row", AnyHashable("days")]
        state[key, as: AnyHashable.self] = days[2].id
        check(state[key, as: AnyHashable.self] == days[2].id && state.surface.isEmpty, "a row choice round-trips through keyed host state")

        let items = days[0].sections.flatMap(\.items)
        let first = items.first { $0.ref == morning }
        check(first?.description == "Summary line" && first?.items.filter { $0.entryId != nil }.map(\.name) == ["Detail"], "the first paragraph is the summary and the remaining blocks are disclosed children")
        check(first?.trailingKind == .toggle && first?.active == false && first?.value == day(0, 11, 59).formatted(date: .omitted, time: .shortened), "rows carry completion and the scheduled time")

        let original = current(noon)
        model.session.select(morning)
        if let target = items.first(where: { $0.ref == noon }) { controls.onToggle?(target) }
        check(current(noon)?.done == true && current(morning)?.done == false, "completion targets the clicked task while another is selected")
        check(current(noon)?.id == original?.id && current(noon)?.text == original?.text, "completion preserves the task block identity and text")
        check(first.map { controls.selected?($0) == true } == true, "row selection reads the session selection")

        model.session.select(agenda)
        let frame = ContentFrame()
        check(frame.parameters(model).sections.map(\.id) == params.sections.map(\.id) && frame.state.values.isEmpty && frame.state.surface.isEmpty, "ContentFrame delegates without preparing or writing state")

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
