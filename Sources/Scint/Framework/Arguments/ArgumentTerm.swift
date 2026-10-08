import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


extension Value { var title: String { rendered.joined(separator: " ") } }

extension Parameter {
    var name: String? {
        switch self {
            case .argument(let name, _, _, _), .reference(let name, _, _, _): name
            case .fixed: nil
        }
    }
}

indirect enum Term {
    case flag(String, Term)
    case toggle, integer, decimal, text, date, moment
    case choice([Value])
    case scale([Value])
    case reference(Reference?)
    case list(Term)
    case group([Argument])

    init(_ template: Value) {
        switch template {
            case .property(.bool): self = .toggle
            case .property(.integer): self = .integer
            case .property(.decimal): self = .decimal
            case .property: self = .text
            case .date: self = .date
            case .when: self = .moment
            case .reference(let ref): self = .reference(ref)
            case .range(let steps): self = .scale(steps)
            case .sequence(let values) where values.isEmpty: self = .reference(nil)
            case .sequence(let values) where values.count == 1: self = .list(Term(values[0]))
            case .sequence(let values): self = .choice(values)
            case .collection(let values) where values.count == 1: self = values.first.map { .flag($0.key, Term($0.value)) } ?? .group([])
            case .collection(let values):
                self = .group(values.sorted { $0.key < $1.key }.map { Argument(name: $0.key, template: $0.value, required: true) })
        }
    }

    var seed: Value? {
        switch self {
            case .flag(_, let inner): inner.seed
            case .toggle: .property(.bool(false))
            case .integer: .property(.integer(0))
            case .decimal: .property(.decimal(0))
            case .text: .property("")
            case .date: .date(.now)
            case .moment: .when(When(.now))
            case .choice(let values), .scale(let values): values.first
            case .reference: nil
            case .list: .sequence([])
            case .group(let arguments):
                arguments.allSatisfy { $0.term.seed != nil }
                ? .collection(Dictionary(uniqueKeysWithValues: arguments.compactMap { argument in argument.term.seed.map { (argument.name, $0) } }))
                : nil
        }
    }

    var leaf: Term { if case .flag(_, let inner) = self { inner.leaf } else { self } }

    static func peel(_ value: Value?, _ flag: String) -> Value? {
        guard case .collection(let values)? = value, values.count == 1, let inner = values[flag] else { return value }
        return inner
    }
}

struct TermDate: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()

            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}

struct TermMoment: View {
    @Binding var value: Value?

    @State private var timed = false

    var when: When? { if case .when(let when)? = value { when } else { nil } }

    func morning(_ date: Date) -> Date { Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date }

    var body: some View {
        Group {
            HStack {
                Text("Date")
                Spacer()

                if let when {
                    DatePicker("", selection: .init(get: { when.date }, set: { value = .when(When($0, repeats: when.repeats)) }), displayedComponents: .date)
                        .labelsHidden()
                }

                Toggle("Date", isOn: .init(get: { when != nil }, set: { on in
                    timed = false
                    value = on ? .when(When(morning(.now))) : nil
                }))
                .labelsHidden()
            }

            if let when {
                HStack {
                    Text("Time")
                    Spacer()

                    if timed {
                        DatePicker("", selection: .init(get: { when.date }, set: { value = .when(When($0, repeats: when.repeats)) }), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }

                    Toggle("Time", isOn: .init(get: { timed }, set: { on in
                        timed = on
                        let hour = (Calendar.current.component(.hour, from: .now) + 1) % 24
                        let moment = on ? Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: when.date) ?? when.date : morning(when.date)
                        value = .when(When(moment, repeats: when.repeats))
                    }))
                    .labelsHidden()
                }

                HStack {
                    Text("Repeat")
                    Spacer()

                    Picker("Repeat", selection: .init(get: { when.repeats }, set: { value = .when(When(when.date, repeats: $0)) })) {
                        ForEach(When.Repeat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .onAppear { timed = when.map { morning($0.date) != $0.date } ?? false }
    }
}

struct TermChoice: View {
    let choices: [Value]
    let placeholder: String
    @Binding var value: Value?

    var body: some View {
        Picker("", selection: .init(get: { value.flatMap { choices.firstIndex(of: $0) } }, set: { value = $0.map { choices[$0] } })) {
            Text(placeholder).tag(Int?.none)
            ForEach(choices.indices, id: \.self) { index in Text(choices[index].title).tag(Int?.some(index)) }
        }
        .labelsHidden()
    }
}

struct TermScale: View {
    let steps: [Value]
    let placeholder: String
    let resting: Value?
    @Binding var value: Value?

    var index: Int { (value ?? resting).flatMap { steps.firstIndex(of: $0) } ?? 0 }

    var body: some View {
        HStack {
            Slider(
                value: .init(get: { Double(index) }, set: { value = steps[min(max(Int($0.rounded()), 0), steps.count - 1)] }),
                in: 0...Double(max(steps.count - 1, 1)),
                step: 1
            )

            Text(value == nil ? placeholder : steps[index].title)
                .foregroundStyle(Style.Foreground.secondary)
        }
    }
}

struct TermReference: View {
    let expected: Reference?
    let placeholder: String
    @Binding var value: Value?

    var options: [Reference] { Self.options(expected) }

    static func options(_ expected: Reference?) -> [Reference] {
        func all<T: Resolvable>(_ type: T.Type) -> [Reference] { Runtime.shared.all(as: type).map { $0.0 } }
        let refs = expected?.type.map { all($0) } ?? all(Space.self)
        return refs.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var artifact: Bool { expected?.type is Artifact.Type }

    var body: some View {
        HStack {
            Picker("", selection: .init(get: { value?.references.first }, set: { value = $0.map(Value.reference) })) {
                Text(placeholder).tag(Reference?.none)
                ForEach(options, id: \.self) { ref in Text(ref.descriptor.name).tag(Reference?.some(ref)) }
            }
            .labelsHidden()

            if artifact {
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    let existing = Runtime.shared.all(as: Artifact.self).first { $0.1.handle.url == url }?.0
                    value = .reference(existing ?? Artifact.new(url.lastPathComponent, url))
                }
            }
        }
    }
}

struct TermList: View {
    let element: Term
    @Binding var value: Value?

    var elements: [Value] { if case .sequence(let values)? = value { values } else { [] } }

    var body: some View {
        VStack(alignment: .trailing) {
            ForEach(elements.indices, id: \.self) { index in
                HStack {
                    TermField(element, value: .init(
                        get: { elements.indices.contains(index) ? elements[index] : nil },
                        set: { replacement in
                            var values = elements
                            if let replacement { values[index] = replacement }
                            else { values.remove(at: index) }
                            value = values.isEmpty ? nil : .sequence(values)
                        }
                    ), placeholder: "Remove", resting: nil)

                    Button {
                        var values = elements
                        values.remove(at: index)
                        value = values.isEmpty ? nil : .sequence(values)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let seed = element.seed {
                Button("Add") { value = .sequence(elements + [seed]) }
            } else {
                TermField(element, value: .init(get: { nil }, set: { if let added = $0 { value = .sequence(elements + [added]) } }), placeholder: "Add…", resting: nil)
            }
        }
    }
}

struct TermGroup: View {
    let arguments: [Argument]
    @Binding var value: Value?

    var fields: [String: Value] { if case .collection(let values)? = value { values } else { [:] } }

    var body: some View {
        VStack(alignment: .trailing) {
            ForEach(arguments) { argument in
                ArgumentControl(argument, value: .init(
                    get: { fields[argument.name] },
                    set: { field in
                        var values = arguments.reduce(into: [String: Value]()) { values, argument in
                            values[argument.name] = fields[argument.name] ?? argument.term.seed
                        }
                        values[argument.name] = field
                        value = values.count == arguments.count ? .collection(values) : nil
                    }
                ))
            }
        }
    }
}

struct TermField: View {
    let term: Term
    let placeholder: String
    let resting: Value?
    @Binding var value: Value?

    init(_ term: Term, value: Binding<Value?>, placeholder: String, resting: Value?) {
        self.term = term
        self.placeholder = placeholder
        self.resting = resting
        self._value = value
    }

    var body: some View {
        switch term {
            case .flag(let flag, let inner):
                TermField(inner, value: .init(get: { Term.peel(value, flag) }, set: { value = $0 }), placeholder: placeholder, resting: resting)

            case .toggle:
                Toggle("", isOn: .init(get: { if case .property(.bool(let on))? = value ?? resting { on } else { false } }, set: { value = .property(.bool($0)) }))
                    .labelsHidden()

            case .integer:
                TextField("", value: .init(get: { if case .property(.integer(let number))? = value { number } else { nil } }, set: { value = $0.map { .property(.integer($0)) } }), format: .number, prompt: Text(placeholder))

            case .decimal:
                TextField("", value: .init(get: { if case .property(.decimal(let number))? = value { number } else { nil } }, set: { value = $0.map { .property(.decimal($0)) } }), format: .number, prompt: Text(placeholder))

            case .text:
                TextField("", text: .init(get: { if case .property(.string(let text))? = value { text } else { "" } }, set: { value = $0.isEmpty ? nil : .property(.string($0)) }), prompt: Text(placeholder))

            case .date:
                TermDate(date: .init(get: { if case .date(let date)? = value { date } else { .now } }, set: { value = .date($0) }))

            case .moment:
                TermMoment(value: $value)

            case .choice(let choices):
                TermChoice(choices: choices, placeholder: placeholder, value: $value)

            case .scale(let steps) where steps.isEmpty:
                EmptyView()

            case .scale(let steps):
                TermScale(steps: steps, placeholder: placeholder, resting: resting, value: $value)

            case .reference(let expected):
                TermReference(expected: expected, placeholder: placeholder, value: $value)

            case .list(let element):
                TermList(element: element, value: $value)

            case .group(let arguments):
                TermGroup(arguments: arguments, value: $value)
        }
    }
}
