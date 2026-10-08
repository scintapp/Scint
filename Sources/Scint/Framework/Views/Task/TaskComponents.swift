import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskMomentField: NSViewRepresentable {
    let date: Date
    let elements: NSDatePicker.ElementFlags
    var onChange: (Date) -> Void
    var onEnd: () -> Void

    final class Picker: NSDatePicker {
        var onEnd: () -> Void = {}
        private var monitor: Any?

        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }

        override func becomeFirstResponder() -> Bool {
            let became = super.becomeFirstResponder()
            if became, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                    guard let self, event.window == self.window, !self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                            else { return event }
                    self.window?.makeFirstResponder(nil)
                    return event
                }
            }
            return became
        }

        override func resignFirstResponder() -> Bool {
            let resigned = super.resignFirstResponder()
            if resigned {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                onEnd()
            }
            return resigned
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 || event.keyCode == 53 { window?.makeFirstResponder(nil) }
            else { super.keyDown(with: event) }
        }
    }

    @MainActor final class Coordinator: NSObject {
        var onChange: (Date) -> Void = { _ in }
        @objc func changed(_ picker: NSDatePicker) { onChange(picker.dateValue) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Self.Context) -> Picker {
        let picker = Picker()
        picker.datePickerStyle = .textField
        picker.isBezeled = false
        picker.isBordered = false
        picker.drawsBackground = false
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        return picker
    }

    func updateNSView(_ picker: Picker, context: Self.Context) {
        context.coordinator.onChange = onChange
        picker.onEnd = onEnd
        picker.datePickerElements = elements
        if picker.dateValue != date { picker.dateValue = date }
    }
}

struct TaskMoment: View {
    let ref: Reference
    let placeholder: String
    let symbol: String
    let components: DatePickerComponents

    @Environment(\.controlSize) private var controlSize
    @State private var editing = false

    var task: Block? { Document.with(ref, { $0.blocks.first }) ?? nil }
    var when: When? { if case .task(_, _, _, let when)? = task { when } else { nil } }
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
                TaskMomentField(
                    date: when?.date ?? .now,
                    elements: components.contains(.date) ? .yearMonthDay : .hourMinute,
                    onChange: { moment in
                        guard case .task(let id, let text, let done, let when)? = task else { return }
                        Document.update(ref) { $0.update(.task(id, text, done, When(moment, repeats: when?.repeats ?? .never)), at: 0) }
                    },
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

    var task: Block? { Document.with(ref, { $0.blocks.first }) ?? nil }
    var when: When? { if case .task(_, _, _, let when)? = task { when } else { nil } }
    var repeating: Bool { (when?.repeats ?? .never) != .never }

    var body: some View {
        SwiftUI.Menu {
            ForEach(When.Repeat.allCases, id: \.self) { repeats in
                Toggle(repeats.rawValue.capitalized, isOn: .init(
                    get: { when?.repeats == repeats },
                    set: { _ in
                        guard case .task(let id, let text, let done, let when)? = task else { return }
                        Document.update(ref) { $0.update(.task(id, text, done, When(when?.date ?? .now, repeats: repeats)), at: 0) }
                    }
                ))
            }
        } label: {
            Image(systemName: "repeat")
        }
        .menuStyle(.button)
        .buttonStyle(.soft)
        .fixedSize()
        .disabled(when == nil)
        .opacity(repeating ? 1 : Style.Opacity.inactive)
    }
}

struct TaskSpace: View {
    let ref: Reference
    let scope: Reference

    var data: Int? { Document.with(ref, { $0.blocks.firstIndex { if case .data = $0 { true } else { false } } }) ?? nil }

    var values: [String: Value] {
        Document.with(ref, { $0.blocks.lazy.compactMap {
            if case .data(_, .collection(let values)) = $0 { values } else { nil } }.first ?? [:] }) ?? [:]
    }

    var space: Reference? { values["space"]?.references.first }

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
            var values = values
            values["space"] = item.ref.map(Value.reference)
            Document.update(ref) { document in
                guard let data, case .data(let id, _) = document.blocks[data] else { return }
                document.update(.data(id, .collection(values)), at: data)
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

    var selected: Reference? {
        Document.with(ref, { $0.blocks.lazy.compactMap {
            if case .command(let ref) = $0 { ref } else { nil } }.first }) ?? nil
    }

    var library: [Reference] {
        Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    var body: some View {
        LoadButton(items: library.map { ItemParams(ref: $0, name: $0.descriptor.name, active: $0 == selected) }) { item in
            guard let option = item.ref, option != selected else { return }
            Document.update(ref) { document in
                if let selected, let index = document.blocks.firstIndex(of: .command(selected)) { document.delete(at: index) }
                document.insert(.command(option), at: 1)
                guard let data = document.blocks.firstIndex(where: { if case .data = $0 { true } else { false } }), case .data(let id, let value) = document.blocks[data]
                        else { return }
                let space: Value? = if case .collection(let values) = value { values["space"] } else { nil }
                document.update(.data(id, .collection(space.map { ["space": $0] } ?? [:])), at: data)
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

    var task: Block? { Document.with(ref, { $0.blocks.first }) ?? nil }
    var ready: Bool { if case .task(_, _, _, _?)? = task { true } else { false } }

    var scheduled: Bool {
        guard
            case .task(_, _, false, _)? = task,
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
