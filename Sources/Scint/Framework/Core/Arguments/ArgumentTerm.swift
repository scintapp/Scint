import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


extension Value { var title: String { rendered.joined(separator: " ") } }

extension Schema {
    var seed: Value? {
        switch bare {
            case .bool: .property(.bool(false))
            case .integer: .property(.integer(0))
            case .decimal: .property(.decimal(0))
            case .string: .property("")
            case .date: .date(.now)
            case .options, .range: choices.first
            case .reference, .command: nil
            case .list: .sequence([])
            case .dictionary(let fields):
                fields.values.allSatisfy { $0.seed != nil } ? .collection(fields.compactMapValues(\.seed)) : nil
            case .default, .required: nil
        }
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
    let element: Schema
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
                            values[argument.name] = fields[argument.name] ?? argument.schema.seed
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
    let schema: Schema
    let placeholder: String
    let resting: Value?
    @Binding var value: Value?

    init(_ schema: Schema, value: Binding<Value?>, placeholder: String, resting: Value?) {
        self.schema = schema
        self.placeholder = placeholder
        self.resting = resting
        self._value = value
    }

    var body: some View {
        switch schema.bare {
            case .bool:
                Toggle("", isOn: .init(get: { if case .property(.bool(let on))? = value ?? resting { on } else { false } }, set: { value = .property(.bool($0)) }))
                    .labelsHidden()

            case .integer:
                TextField("", value: .init(get: { if case .property(.integer(let number))? = value { number } else { nil } }, set: { value = $0.map { .property(.integer($0)) } }), format: .number, prompt: Text(placeholder))

            case .decimal:
                TextField("", value: .init(get: { if case .property(.decimal(let number))? = value { number } else { nil } }, set: { value = $0.map { .property(.decimal($0)) } }), format: .number, prompt: Text(placeholder))

            case .string:
                TextField("", text: .init(get: { if case .property(.string(let text))? = value { text } else { "" } }, set: { value = $0.isEmpty ? nil : .property(.string($0)) }), prompt: Text(placeholder))

            case .date:
                TermDate(date: .init(get: { if case .date(let date)? = value { date } else { .now } }, set: { value = .date($0) }))

            case .options:
                TermChoice(choices: schema.choices, placeholder: placeholder, value: $value)

            case .range where schema.choices.isEmpty:
                EmptyView()

            case .range:
                TermScale(steps: schema.choices, placeholder: placeholder, resting: resting, value: $value)

            case .reference(let expected):
                TermReference(expected: expected, placeholder: placeholder, value: $value)

            case .command(let inner) where !inner.choices.isEmpty:
                TermChoice(choices: inner.choices, placeholder: placeholder, value: $value)

            case .command(let inner):
                TermField(inner, value: $value, placeholder: placeholder, resting: resting)

            case .list(let element):
                TermList(element: element, value: $value)

            case .dictionary(let fields):
                TermGroup(arguments: fields.keys.sorted().map { Argument(name: $0, schema: fields[$0]!) }, value: $value)

            case .default, .required:
                EmptyView()
        }
    }
}
