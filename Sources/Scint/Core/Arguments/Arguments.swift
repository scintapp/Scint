import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


extension Value {
    var title: String { rendered.joined(separator: " ") }
}

extension Parameter {
    var name: String? {
        switch self {
            case .argument(let name, _, _, _), .command(let name, _), .callback(let name, _): name
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
            case .bool: self = .toggle
            case .integer: self = .integer
            case .decimal: self = .decimal
            case .string: self = .text
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
            case .toggle: .bool(false)
            case .integer: .integer(0)
            case .decimal: .decimal(0)
            case .text: .string("")
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

struct Argument: Identifiable {
    let name: String
    let template: Value
    let required: Bool
    let fallback: Value?

    var id: String { name }
    var term: Term { Term(template) }
    var resting: Value? { flags.reduce(fallback) { Term.peel($0, $1) } }
    var placeholder: String { resting.map { "Default (\($0.title))" } ?? (required ? "Required" : "Default") }

    var flags: [String] {
        var flags: [String] = []
        var current = template
        while case .collection(let values) = current, values.count == 1, let entry = values.first {
            flags.append(entry.key)
            current = entry.value
        }
        return flags
    }

    var label: String { Self.label(name) }

    static func label(_ text: String) -> String {
        text.reduce(into: "") { label, character in
            if character == "-" || character == "_" { label.append(" ") }
            else {
                if character.isUppercase, !label.isEmpty { label.append(" ") }
                label.append(character)
            }
        }.capitalized
    }

    init(name: String, template: Value, required: Bool = false, fallback: Value? = nil) {
        self.name = name
        self.template = template
        self.required = required
        self.fallback = fallback
    }

    init?(_ parameter: Parameter) {
        switch parameter {
            case .argument(let name, let type, let required, let fallback): self.init(name: name, template: type, required: required, fallback: fallback)
            case .command(let name, let ref): self.init(name: name, template: ref, required: true, fallback: ref)
            case .callback(let name, let open): self.init(name: name, template: open, required: true, fallback: nil)
            case .fixed: return nil
        }
    }

    func accepts(_ value: Value) -> Bool { (try? template.construct(value, name: name)) != nil }

    static func parameters(of owner: Reference, values: [String: Value] = [:]) -> [Parameter] {
        if let parameters = Command.with(owner, { $0.parameters }) { return parameters }
        let own = Harness.with(owner, { $0.parameters }) ?? []
        let commands = own.compactMap { parameter -> Reference? in
            let value: Value? = switch parameter {
                case .argument(let name, _, _, let fallback): values[name] ?? fallback
                case .command(let name, let ref): values[name] ?? ref
                case .callback, .fixed: nil
            }
            return value?.references.first { $0.type is Command.Type }
        }
        return commands.reduce(own) { merged, command in merge(merged, into: Command.with(command, { $0.parameters }) ?? []) }
    }

    static func merge(_ own: [Parameter], into inherited: [Parameter]) -> [Parameter] {
        let names = Set(own.compactMap(\.name))
        let merged = own.map { parameter -> Parameter in
            guard let name = parameter.name,
                  case .argument(_, let type, let required, let fallback) = parameter,
                  case .argument(_, _, let inheritedRequired, let inheritedFallback)? = inherited.first(where: { $0.name == name })
            else { return parameter }
            return .argument(name: name, type: type, required: required || inheritedRequired, default: fallback ?? inheritedFallback)
        }
        return merged + inherited.filter { $0.name.map { !names.contains($0) } ?? true }
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
                    let existing = Runtime.shared.all(as: Artifact.self).first { $0.1.handler.url == url }?.0
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
                Toggle("", isOn: .init(get: { if case .bool(let on)? = value ?? resting { on } else { false } }, set: { value = .bool($0) }))
                    .labelsHidden()

            case .integer:
                TextField("", value: .init(get: { if case .integer(let number)? = value { number } else { nil } }, set: { value = $0.map(Value.integer) }), format: .number, prompt: Text(placeholder))

            case .decimal:
                TextField("", value: .init(get: { if case .decimal(let number)? = value { number } else { nil } }, set: { value = $0.map(Value.decimal) }), format: .number, prompt: Text(placeholder))

            case .text:
                TextField("", text: .init(get: { if case .string(let text)? = value { text } else { "" } }, set: { value = $0.isEmpty ? nil : .string($0) }), prompt: Text(placeholder))

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

struct ArgumentStyleConfiguration {
    let argument: Argument
    let label: AnyView
    let content: AnyView
    let value: Binding<Value?>
}

protocol ArgumentStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = ArgumentStyleConfiguration

    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

struct AutomaticArgumentStyle: ArgumentStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if case .moment = configuration.argument.term { configuration.content }
            else {
                HStack {
                    configuration.label
                    Spacer(minLength: 12)
                    configuration.content
                }
            }
        }
        .contextMenu {
            Button("Reset to Default") { configuration.value.wrappedValue = nil }
        }
    }
}

struct PlainArgumentStyle: ArgumentStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.content }
}

struct ArgumentToken: View {
    let configuration: ArgumentStyleConfiguration

    @State private var presented = false

    var value: Value? { configuration.argument.flags.reduce(configuration.value.wrappedValue) { Term.peel($0, $1) } }
    var title: String { (value ?? configuration.argument.resting)?.title ?? configuration.argument.label }

    var body: some View {
        Button { presented.toggle() } label: {
            Text(title)
                .foregroundStyle(value == nil ? Style.Foreground.subtle : Style.Foreground.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Style.Background.selection, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $presented) {
            configuration.content
                .padding(12)
                .frame(minWidth: 220)
        }
    }
}

struct TokenArgumentStyle: ArgumentStyle {
    func makeBody(configuration: Configuration) -> some View { ArgumentToken(configuration: configuration) }
}

extension ArgumentStyle where Self == AutomaticArgumentStyle {
    static var automatic: Self { .init() }
}

extension ArgumentStyle where Self == PlainArgumentStyle {
    static var plain: Self { .init() }
}

extension ArgumentStyle where Self == TokenArgumentStyle {
    static var token: Self { .init() }
}

extension EnvironmentValues {
    @Entry var argumentStyle: any ArgumentStyle = AutomaticArgumentStyle()
}

extension View {
    func argumentStyle(_ style: some ArgumentStyle) -> some View { environment(\.argumentStyle, style) }
}

struct ArgumentControl<Label: View>: View {
    let argument: Argument
    let label: Label
    @Binding var value: Value?
    @Environment(\.argumentStyle) private var style

    init(_ argument: Argument, value: Binding<Value?>, @ViewBuilder label: () -> Label) {
        self.argument = argument
        self.label = label()
        self._value = value
    }

    var body: some View {
        let accepted = Binding<Value?>(get: { value }, set: { if $0.map(argument.accepts) ?? true { value = $0 } })
        let content = TermField(argument.term, value: accepted, placeholder: argument.placeholder, resting: argument.resting)
        AnyView(style.makeBody(configuration: .init(argument: argument, label: AnyView(label), content: AnyView(content), value: accepted)))
    }
}

extension ArgumentControl where Label == Text {
    init(_ argument: Argument, value: Binding<Value?>) {
        self.init(argument, value: value) { Text(argument.label) }
    }
}

struct ArgumentApply {
    let pending: Bool
    let action: () -> Void

    func callAsFunction() { action() }
}

struct ArgumentDraft<Content: View>: View {
    @Binding var values: [String: Value]
    let content: (Binding<[String: Value]>, ArgumentApply) -> Content

    @State private var draft: [String: Value]?

    init(values: Binding<[String: Value]>, @ViewBuilder content: @escaping (Binding<[String: Value]>, ArgumentApply) -> Content) {
        self._values = values
        self.content = content
    }

    var body: some View {
        content(
            .init(get: { draft ?? values }, set: { draft = $0 }),
            ArgumentApply(pending: draft.map { $0 != values } ?? false) {
                if let draft { values = draft }
                draft = nil
            }
        )
    }
}

struct ArgumentConfig {
    let space: Reference
    let owner: Reference

    var parameters: [Parameter] { Argument.parameters(of: owner) }

    var values: [String: Value] {
        if case .collection(let values)? = Space.with(space, { $0.config[owner] }) ?? nil { values } else { [:] }
    }

    func store(_ values: [String: Value]) {
        Space.with(space) { $0.configure(values.isEmpty ? nil : .collection(values), for: owner) }
    }
}

extension Argument {
    static func clock(_ key: String) -> Bool { key.lowercased().contains("time") }

    static func directory(_ key: String) -> Bool {
        let key = key.lowercased()
        return key.contains("dir") || key.contains("folder") || key.contains("path")
    }

    static func symbol(_ key: String) -> String {
        if directory(key) { return "folder" }
        if clock(key) { return "clock" }

        let key = key.lowercased()
        return switch true {
            case key.contains("model"): "cpu"
            case key.contains("effort"): "lightbulb.max"
            case key.contains("sandbox"), key.contains("permission"): "lock.shield"
            case key.contains("command"), key == "action": "switch.2"
            case key.contains("target"), key.contains("space"): "square.stack"
            case key.contains("schedule"), key.contains("date"), key == "at", key == "when": "calendar"
            case key.contains("repeat"), key.contains("every"): "repeat"
            case key.contains("url"), key.contains("endpoint"): "link"
            case key.contains("interval"), key.contains("latency"), key.contains("timeout"): "timer"
            case key.contains("event"): "bolt"
            case key.contains("label"), key.contains("name"): "tag"
            case key.contains("check"), key.contains("query"): "magnifyingglass"
            default: "slider.horizontal.3"
        }
    }

    @MainActor func item(_ value: Value?) -> ItemParams? {
        let current = flags.reduce(value) { Term.peel($0, $1) }
        let shown = (current ?? resting)?.rendered.last ?? ""
        let detail = current?.references.first?.descriptor.name ?? current.map { Self.label($0.title) } ?? "Default"
        let choices: ([Value]) -> [ItemParams] = { values in
            values.compactMap(\.rendered.last).map { ItemParams(key: name, name: Self.label($0), value: $0) }
        }

        var kind: ItemParams.TrailingKind
        var items: [ItemParams] = []
        var active = true
        switch term.leaf {
            case .toggle:
                kind = .toggle
                active = current == .bool(true) || current == .string("true")
            case .integer, .decimal, .text:
                kind = .field
            case .date:
                kind = .date
                active = current != nil
            case .moment:
                kind = .moment
                active = current != nil
            case .choice(let values):
                kind = .picker
                items = choices(values)
            case .scale(let values):
                kind = .range
                items = choices(values)
            case .reference(let expected):
                kind = .load
                items = [ItemParams(key: name, name: "Default", image: "circle.dashed", tint: Style.Foreground.secondary, active: current == nil)]
                    + TermReference.options(expected).map { ItemParams(ref: $0, key: name, name: $0.descriptor.name, active: current?.references.first == $0) }
            case .flag, .list, .group:
                return nil
        }

        let image = current?.references.first.map { Iconography.icon(for: $0).symbol } ?? Self.symbol(name)
        return ItemParams(key: name, name: label, image: image, tint: Style.Foreground.secondary, trailingKind: kind, value: shown, description: detail, active: active, items: items)
    }

    static func controls(_ write: @escaping (_ key: String, _ value: Value?) -> Void) -> Controls {
        func set(_ key: String?, _ value: Value?) { if let key { write(key, value) } }

        return .init(
            onToggle: { item in
                switch item.trailingKind {
                    case .moment: set(item.key, item.active ? nil : .when(When(.now)))
                    case .date, .time: set(item.key, item.active ? nil : .date(.now))
                    default: set(item.key, .bool(!item.active))
                }
            },
            onChange: { item, selection in set(item.key, selection.value.map(Value.string)) },
            onValueChange: { item, text in
                if item.trailingKind == .moment, let moment = Value.formatter.date(from: text) { return set(item.key, .when(When(moment))) }
                set(item.key, text.isEmpty ? nil : .string(text))
            },
            onSelect: { item in set(item.key, item.ref.map(Value.reference)) }
        )
    }
}

struct Arguments: View {
    let parameters: [Parameter]
    @Binding var values: [String: Value]

    init(_ parameters: [Parameter], values: Binding<[String: Value]>) {
        self.parameters = parameters
        self._values = values
    }

    init(for owner: Reference?, values: Binding<[String: Value]>) {
        self.init(owner.map { Argument.parameters(of: $0, values: values.wrappedValue) } ?? [], values: values)
    }

    var arguments: [Argument] { parameters.compactMap { Argument($0) } }

    var body: some View {
        ForEach(arguments) { argument in
            ArgumentControl(argument, value: .init(get: { values[argument.name] }, set: { values[argument.name] = $0 }))
        }
    }
}

#Preview {
    @Previewable @State var selected: String?
    @Previewable @State var values: [String: Value] = [:]

    let sandbox: Value = .collection(["--sandbox": .sequence([.string("read-only"), .string("workspace-write"), .string("danger-full-access")])])

    let harnesses: [(name: String, harness: [Parameter], command: [Parameter])] = [
        ("Agent", [
            .argument(name: "sandbox", type: sandbox, default: .collection(["--sandbox": .string("read-only")])),
            .argument(name: "input", type: .string(""), required: true),
            .argument(name: "brief", type: .string("")),
        ], [
            .fixed(.string("exec")),
            .argument(name: "model", type: .collection(["--model": .sequence([.string("gpt-6-astra"), .string("gpt-5.5")])])),
            .argument(name: "effort", type: .collection(["-c": .collection(["model_reasoning_effort": .range([.string("low"), .string("medium"), .string("high"), .string("xhigh")])])])),
            .argument(name: "sandbox", type: sandbox, default: .collection(["--sandbox": .string("workspace-write")])),
            .argument(name: "maxTurns", type: .collection(["--max-turns": .integer(0)])),
            .argument(name: "input", type: .string("")),
        ]),
        ("Transcode", [], [
            .argument(name: "format", type: .collection(["--format": .sequence([.string("mp4"), .string("mov"), .string("webm")])]), required: true),
            .argument(name: "quality", type: .collection(["--quality": .range([.string("draft"), .string("good"), .string("best")])]), default: .string("good")),
            .argument(name: "bitrate", type: .collection(["--bitrate": .integer(0)])),
            .argument(name: "trim", type: .collection(["start": .decimal(0), "end": .decimal(0)])),
            .argument(name: "overwrite", type: .collection(["-y": .bool(false)])),
            .argument(name: "output", type: .string(""), required: true),
        ]),
        ("Observe", [
            .argument(name: "when", type: .when(When(.distantPast))),
            .argument(name: "note", type: .string("")),
        ], []),
        ("Publish", [
            .argument(
                name: "visibility",
                type: .collection(["--visibility": .sequence([.string("public"), .string("unlisted"), .string("private")])]),
                default: .collection(["--visibility": .string("unlisted")])
            ),
        ], [
            .argument(name: "channels", type: .collection(["--channel": .sequence([.string("")])]), required: true),
            .argument(name: "visibility", type: .collection(["--visibility": .sequence([.string("public"), .string("unlisted"), .string("private")])])),
            .argument(name: "dryRun", type: .collection(["--dry-run": .bool(false)])),
        ]),
        ("Empty", [], []),
    ]

    let parameters = harnesses.first { $0.name == selected }.map { Argument.merge($0.harness, into: $0.command) } ?? []

    VStack(alignment: .leading, spacing: 0) {
        Picker("Harness", selection: $selected) {
            Text("None").tag(String?.none)
            ForEach(harnesses, id: \.name) { harness in Text(harness.name).tag(String?.some(harness.name)) }
        }
        .fixedSize()
        .padding()

        if let selected {
            ArgumentDraft(values: $values) { draft, apply in
                Form {
                    Arguments(parameters, values: draft)

                    Button("Apply") { apply() }
                        .disabled(!apply.pending)
                        .keyboardShortcut(.defaultAction)
                }
                .formStyle(.grouped)
                .toggleStyle(.switch)
            }
            .id(selected)

            HStack {
                Text(selected)
                Arguments(parameters, values: $values)
            }
            .argumentStyle(.token)
            .padding()

            ArgumentLine(parameters, values: values)
                .padding()
        }

        Spacer(minLength: 0)
    }
    .frame(width: 560, height: 760)
    .onChange(of: selected) { values = [:] }
}
