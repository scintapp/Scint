import SwiftUI
import ScintRuntime
import ScintComponents


extension ScintRuntime.Document {
    /// The task this document is, when its header says so.
    var task: (id: UUID, text: String, done: Bool)? {
        if case .task(let id, let text, let done)? = blocks.dropFirst().first { (id, text, done) } else { nil }
    }

    /// The harness of the space it lives in, which runs it.
    var harness: Reference? { Space.with(origin, { $0.harness }) ?? nil }

    /// When it runs, read from the arguments of the command its harness starts with.
    var schedule: (moment: Date?, repeats: When.Repeat) {
        let values = harness.flatMap { command(.start, of: $0) }.map(values) ?? [:]
        let moment: Date? = switch values["date"] {
            case .date(let date)?: date
            case .property(.string(let text))?: Value.formatter.date(from: text)
            default: nil
        }
        let repeats: When.Repeat = if case .property(.string(let raw))? = values["repeat"] { When.Repeat(rawValue: raw) ?? .never } else { .never }
        return (moment, repeats)
    }

    mutating func schedule(_ moment: Date, repeats: When.Repeat) {
        guard let harness, let command = command(.start, of: harness) else { return }
        metadata(.date(moment), "date", for: command)
        metadata(.date(moment), "time", for: command)
        metadata(.property(.string(repeats.rawValue)), "repeat", for: command)
    }
}

struct TaskMoment: View {
    let ref: Reference
    let placeholder: String
    let symbol: String
    let components: DatePickerComponents

    @Environment(\.controlSize) private var controlSize
    @State private var editing = false

    var moment: Date? { Document.with(ref, { $0.schedule.moment }) ?? nil }
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
                MomentField(
                    date: moment ?? .now,
                    elements: components.contains(.date) ? .yearMonthDay : .hourMinute,
                    onChange: { moment in Document.update(ref) { $0.schedule(moment, repeats: $0.schedule.repeats) } },
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

struct TaskTime: View {
    let ref: Reference

    var body: some View {
        TaskMoment(ref: ref, placeholder: "Date", symbol: "calendar", components: [.date])
        TaskMoment(ref: ref, placeholder: "Time", symbol: "clock", components: [.hourAndMinute])
    }
}

struct TaskRepeat: View {
    let ref: Reference

    var schedule: (moment: Date?, repeats: When.Repeat)? { Document.with(ref, { $0.schedule }) }
    var repeating: Bool { (schedule?.repeats ?? .never) != .never }

    var body: some View {
        SwiftUI.Menu {
            ForEach(When.Repeat.allCases, id: \.self) { repeats in
                Toggle(repeats.rawValue.capitalized, isOn: .init(
                    get: { schedule?.repeats == repeats },
                    set: { _ in Document.update(ref) { $0.schedule($0.schedule.moment ?? .now, repeats: repeats) } }
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

struct TaskSpace: View {
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
        LoadButton(items: items) { item in
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

struct TaskCommand: View {
    let ref: Reference

    var harness: Reference? { Document.with(ref, { $0.harness }) ?? nil }
    var selected: Reference? { harness.flatMap { harness in Document.with(ref, { $0.command(.update, of: harness) }) ?? nil } }

    var library: [Reference] {
        Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    var body: some View {
        LoadButton(items: library.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == selected) }) { item in
            guard let option = item.ref, option != selected, let harness, let slot = Harness.with(harness, { $0.signatures[.update]?.inputs.first?.name }) ?? nil
            else { return }
            Document.update(ref) { $0.metadata(.reference(option), slot, for: harness) }
        } label: {
            if let selected { Label { Text(selected.descriptor.name) } icon: { Iconography.icon(for: selected) } }
            else { Label("Command", systemImage: "switch.2") }
        }
        .buttonStyle(.soft)
    }
}

struct TaskScheduleButton: View {
    var ref: Reference
    var onStart: () -> Void
    var onStop: () -> Void

    var ready: Bool { (Document.with(ref, { $0.schedule.moment }) ?? nil) != nil }

    var scheduled: Bool {
        guard
            Document.with(ref, { $0.task?.done }) == false,
            let origin = Document.with(ref, { $0.origin }),
            let transcript = Runtime.shared.resolve().first(where: { $0.space == origin })?.transcript,
            let entries = Transcript.with(transcript, { $0.entries })
                else { return false }

        let events = entries.compactMap { entry -> Bool? in
            switch entry {
                case .signal(_, .start(let input), _) where input == ref: true
                case .signal(_, .cancel, _): false
                default: nil
            }
        }
        return events.last ?? false
    }


    var body: some View {
        ZStack {
            Button { onStart() } label: { Image(systemName: "calendar.badge.plus") }
                .buttonStyle(.soft)
                .controlSize(.small)
                .opacity(scheduled ? 0 : 1)
                .disabled(!ready)

            Button { onStop() } label: { Image(systemName: "calendar.badge.checkmark") }
                .buttonStyle(.soft)
                .controlSize(.small)
                .opacity(scheduled ? 1 : 0)
                .disabled(!scheduled)
        }
    }
}

struct TaskField: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            TextEditor(text: .constant("Validate edge cases and error handling for command runner state transitions, including cancellation and timeout behavior."))
                .font(.body)
                .frame(height: 82)
                .scrollContentBackground(.hidden)
                .padding(7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical, 12)
    }
}

struct TasksCompleted: View {
    var completed: Int
    var showsCompleted: Bool
    var onToggleCompleted: () -> Void
    var onClearCompleted: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4 + 1) {
                Text("\(completed) Completed")
                    .foregroundStyle(Style.Foreground.secondary)

                Button("Clear", action: onClearCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(completed > 0 ? Style.Tint.task.bright : Style.Foreground.secondary)
                    .disabled(completed == 0)

                Spacer()

                Button(showsCompleted ? "Hide" : "Show", action: onToggleCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(Style.Tint.task.bright)
            }
            .font(.system(size: 13, weight: .regular))

            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: 0.5)
        }
    }
}
