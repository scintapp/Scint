import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskDate: View {
    let ref: Reference
    let placeholder: String
    let symbol: String
    let components: DatePickerComponents

    @Environment(\.controlSize) private var controlSize
    @State private var editing = false

    var moment: Date? { Document.with(ref, { TaskHeader.schedule($0).moment }) ?? nil }
    var height: CGFloat { Style.Dimension.control(controlSize) }

    var title: String? {
        moment.map { moment in
            if components.contains(.date) {
                Calendar.current.isDateInToday(moment) ? "Today"
                : Calendar.current.isDateInTomorrow(moment) ? "Tomorrow"
                : moment.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            } else {
                moment.formatted(date: .omitted, time: .shortened)
            }
        }
    }

    var body: some View {
        if editing {
            Label {
                DateField(
                    date: moment ?? .now,
                    elements: components.contains(.date) ? .yearMonthDay : .hourMinute,
                    onChange: { moment in Document.update(ref) { TaskHeader.schedule(&$0, moment, repeats: TaskHeader.schedule($0).repeats) } },
                    onEnd: { editing = false }
                )
                .fixedSize()
            } icon: {
                Image(systemName: symbol)
            }
            .padding(.horizontal, height / 2.5)
            .frame(minHeight: height)
            .surface(Style.Shape.control)
        } else {
            Button { editing = true } label: { Label(title ?? placeholder, systemImage: symbol) }
                .buttonStyle(.soft)
        }
    }
}

struct TaskRepeat: View {
    let ref: Reference

    var schedule: (moment: Date?, repeats: When.Repeat)? { Document.with(ref, { TaskHeader.schedule($0) }) }
    var repeating: Bool { (schedule?.repeats ?? .never) != .never }

    var body: some View {
        SwiftUI.Menu {
            ForEach(When.Repeat.allCases, id: \.self) { repeats in
                Toggle(repeats.rawValue.capitalized, isOn: .init(
                    get: { schedule?.repeats == repeats },
                    set: { _ in Document.update(ref) { TaskHeader.schedule(&$0, TaskHeader.schedule($0).moment ?? .now, repeats: repeats) } }
                ))
            }
        } label: {
            Image(systemName: "repeat")
        }
        .menuStyle(.button)
        .buttonStyle(.soft)
        .fixedSize()
        .disabled(schedule?.moment == nil)
        .opacity(repeating ? 1 : Style.Opacity.inactive)
    }
}

struct TaskTarget: View {
    let ref: Reference
    let scope: Reference

    var space: Reference? { Document.with(ref, { document in document.metadata.flatMap { $0.space == document.origin ? nil : $0.space } }) ?? nil }

    var spaces: [Reference] {
        var spaces: [Reference] = []
        Runtime.shared.walk(from: scope) { _, ref, _ in if ref != scope { spaces.append(ref) } }
        return spaces
    }

    var items: [ItemParams] {
        [ItemParams(name: "None", image: "circle.dashed", tint: Style.Foreground.secondary, active: space == nil)]
        + spaces.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == space) }
    }

    var body: some View {
        LoadMenu(items: items) { item in
            Document.update(ref) { document in
                guard let metadata = document.metadata else { return }
                document.update(.metadata(item.ref ?? document.origin, metadata.values), at: 0)
            }
        } label: {
            if let space { Label { Text(space.descriptor.name) } icon: { Iconography.icon(for: space) } }
            else { Label("Space", systemImage: "square.stack") }
        }
        .buttonStyle(.soft)
    }
}

struct TaskAction: View {
    let ref: Reference

    var harness: Reference? { Document.with(ref, { $0.origin }).flatMap { Space.with($0, { $0.harness }) ?? nil } }
    var selected: Reference? { harness.flatMap { harness in Document.with(ref, { $0.command(.update, of: harness) }) ?? nil } }

    var library: [Reference] {
        Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    var body: some View {
        LoadMenu(items: library.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == selected) }) { item in
            guard let option = item.ref, option != selected, let harness, let slot = Interface.with(harness, { $0.signatures[.update]?.inputs.first?.name }) ?? nil
                    else { return }
            Document.update(ref) { $0.metadata(.reference(option), slot, for: harness) }
        } label: {
            if let selected { Label { Text(selected.descriptor.name) } icon: { Iconography.icon(for: selected) } }
            else { Label("Command", systemImage: "switch.2") }
        }
        .buttonStyle(.soft)
    }
}
