import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskMoment: View {
    let ref: Reference
    let placeholder: String
    let symbol: String
    let components: DatePickerComponents

    @Environment(\.controlSize) private var controlSize
    @State private var editing = false
    @FocusState private var focused: Bool

    var when: When? { Sheet.with(ref, { $0.when }) ?? nil }
    var height: CGFloat { Style.Dimension.control(controlSize) }

    var title: String? {
        when.map { when in
            if components.contains(.date) {
                Calendar.current.isDateInToday(when.date) ? "Today"
                : Calendar.current.isDateInTomorrow(when.date) ? "Tomorrow"
                : when.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            } else {
                when.date.formatted(date: .omitted, time: .shortened)
            }
        }
    }

    var body: some View {
        if editing {
            Label {
                DatePicker(
                    "",
                    selection: .init(get: { when?.date ?? .now }, set: { moment in Sheet.update(ref) { $0.when = When(moment, repeats: $0.when?.repeats ?? .never) } }),
                    displayedComponents: components
                )
                .datePickerStyle(.field)
                .labelsHidden()
                .focused($focused)
                .onSubmit { editing = false }
                .onAppear { focused = true }
                .onChange(of: focused) { _, focused in if !focused { editing = false } }
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

    var when: When? { Sheet.with(ref, { $0.when }) ?? nil }

    var body: some View {
        SwiftUI.Menu {
            ForEach(When.Repeat.allCases, id: \.self) { repeats in
                Toggle(repeats.rawValue.capitalized, isOn: .init(
                    get: { when?.repeats == repeats },
                    set: { _ in Sheet.update(ref) { $0.when = When($0.when?.date ?? .now, repeats: repeats) } }
                ))
            }
        } label: {
            Image(systemName: "repeat")
        }
        .menuStyle(.button)
        .buttonStyle(.soft)
        .fixedSize()
        .disabled(when == nil)
        .opacity(when == nil ? Style.Opacity.inactive : 1)
    }
}

struct TaskSpace: View {
    let ref: Reference
    let scope: Reference

    var values: [String: Value] { Sheet.with(ref, { if case .collection(let values)? = $0.data { values } else { [:] } }) ?? [:] }
    var space: Reference? { values["space"]?.references.first }
    var spaces: [Reference] { Space.with(scope) { Array($0.spaces) } ?? [] }

    var items: [ItemParams] {
        [ItemParams(name: "None", image: "circle.dashed", tint: Style.Foreground.secondary, active: space == nil)]
        + spaces.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == space) }
    }

    var body: some View {
        LoadButton(items: items) { item in
            var values = values
            values["space"] = item.ref.map(Value.reference)
            Sheet.update(ref) { $0.data = .collection(values) }
        } label: {
            if let space { Label { Text(space.descriptor.name) } icon: { Iconography.icon(for: space) } }
            else { Label("Space", systemImage: "square.stack") }
        }
        .buttonStyle(.soft)
    }
}

struct TaskCommand: View {
    let ref: Reference

    var selected: Reference? { Sheet.with(ref, { $0.command }) ?? nil }
    var library: [Reference] { Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name } }

    var body: some View {
        LoadButton(items: library.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == selected) }) { item in
            guard let option = item.ref, option != selected else { return }
            Sheet.update(ref) { sheet in
                let space: Value? = if case .collection(let values)? = sheet.data { values["space"] } else { nil }
                sheet.command = option
                if let space { sheet.data = .collection(["space": space]) }
            }
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

    var ready: Bool { Sheet.with(ref) { $0.when } != nil }

    var scheduled: Bool {
        guard
            case let (origin, done)? = Sheet.with(ref, { ($0.origin, $0.done) }), !done,
            let transcript = Runtime.shared.resolve(origin)?.transcript,
            let entries = Transcript.with(transcript, { $0.entries })
                else { return false }

        let events = entries.compactMap { entry -> Bool? in
            switch entry {
                case .event(.start(let value), _) where value.references.contains(ref): true
                case .event(.stop(let value), _) where value.references.contains(ref): false
                default: nil
            }
        }
        return events.last ?? false
    }


    var body: some View {
        ZStack {
            Button { onStart() } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .buttonStyle(.soft)
            .controlSize(.small)
            .opacity(scheduled ? 0 : 1)
            .disabled(!ready)

            Button { onStop() } label: {
                Image(systemName: "calendar.badge.checkmark")
            }
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

struct TaskCompletionIndicator: View {
    var completed: Bool
    var size: CGFloat = 14

    var body: some View {
        Iconography.Icon(
            symbol: completed ? "checkmark.app" : "app",
            tint: completed ? Style.Foreground.secondary : Style.Foreground.secondary,
            sizing: size + 4
        )
        .frame(width: size, height: size)
        .fontWeight(.light)
        .accessibilityHidden(true)
    }
}

struct TaskBlock: View {
    let content: String
    let completed: Bool
    let shape = Style.Shape.panel

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.icon) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, 4)

            Text(content)
                .font(Typography.body)
                .foregroundStyle(completed ? Style.Foreground.secondary : Style.Foreground.primary)
                .strikethrough(completed, color: Style.Foreground.secondary)
                .lineSpacing(Typography.Prose.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
