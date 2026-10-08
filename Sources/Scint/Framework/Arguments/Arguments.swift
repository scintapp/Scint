import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


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
            case .argument(let name, let type, let required, let fallback), .reference(let name, let type, let required, let fallback): self.init(name: name, template: type, required: required, fallback: fallback)
            case .fixed: return nil
        }
    }

    func accepts(_ value: Value) -> Bool { (try? template.construct(value, name: name)) != nil }

    static func parameters(of owner: Reference, values: [String: Value] = [:]) -> [Parameter] {
        Command.with(owner, { Interface($0, values).inputs }) ?? Harness.with(owner, { Interface($0, .start, values).inputs }) ?? []
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
        Space.with(space) { $0.config(values.isEmpty ? nil : .collection(values), for: owner) }
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
                active = current == .property(true) || current == .property("true")
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
                    default: set(item.key, .property(.bool(!item.active)))
                }
            },
            onChange: { item, selection in set(item.key, selection.value.map { .property(.string($0)) }) },
            onValueChange: { item, text in
                if item.trailingKind == .moment, let moment = Value.formatter.date(from: text) { return set(item.key, .when(When(moment))) }
                set(item.key, text.isEmpty ? nil : .property(.string(text)))
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

struct ArgumentLine: View {
    let parameters: [Parameter]
    let values: [String: Value]

    init(_ parameters: [Parameter], values: [String: Value]) {
        self.parameters = parameters
        self.values = values
    }

    var tokens: [(text: String, literal: Bool)] {
        parameters.flatMap { parameter -> [(text: String, literal: Bool)] in
            switch parameter {
                case .fixed(let value):
                    return value.rendered.map { ($0, true) }
                case .argument(let name, let type, let required, let fallback):
                    guard let value = values[name] ?? fallback, let built = try? type.construct(value, name: name)
                            else { return required ? [("‹\(name)›", false)] : [] }
                    return built.rendered.map { ($0, false) }
                case .reference(let name, _, let required, let fallback):
                    guard let value = values[name] ?? fallback
                            else { return required ? [("‹\(name)›", false)] : [] }
                    return [("‹\(value.references.first?.descriptor.name ?? name)›", false)]
            }
        }
    }

    var body: some View {
        tokens.reduce(Text("")) { line, token in
            line + Text(token.text + " ").foregroundStyle(token.literal ? Style.Foreground.subtle : Style.Foreground.primary)
        }
        .font(Typography.code)
        .textSelection(.enabled)
    }
}

#Preview {
    @Previewable @State var selected: String?
    @Previewable @State var values: [String: Value] = [:]

    let sandbox: Value = .collection(["--sandbox": .sequence([.property("read-only"), .property("workspace-write"), .property("danger-full-access")])])

    let harnesses: [(name: String, harness: [Parameter], command: [Parameter])] = [
        ("Agent", [
            .argument(name: "sandbox", type: sandbox, default: .collection(["--sandbox": .property("read-only")])),
            .argument(name: "input", type: .property(""), required: true),
            .argument(name: "brief", type: .property("")),
        ], [
            .fixed(.property("exec")),
            .argument(name: "model", type: .collection(["--model": .sequence([.property("gpt-6-astra"), .property("gpt-5.5")])])),
            .argument(name: "effort", type: .collection(["-c": .collection(["model_reasoning_effort": .range([.property("low"), .property("medium"), .property("high"), .property("xhigh")])])])),
            .argument(name: "sandbox", type: sandbox, default: .collection(["--sandbox": .property("workspace-write")])),
            .argument(name: "maxTurns", type: .collection(["--max-turns": .property(0)])),
            .argument(name: "input", type: .property("")),
        ]),
        ("Transcode", [], [
            .argument(name: "format", type: .collection(["--format": .sequence([.property("mp4"), .property("mov"), .property("webm")])]), required: true),
            .argument(name: "quality", type: .collection(["--quality": .range([.property("draft"), .property("good"), .property("best")])]), default: .property("good")),
            .argument(name: "bitrate", type: .collection(["--bitrate": .property(0)])),
            .argument(name: "trim", type: .collection(["start": .property(0.0), "end": .property(0.0)])),
            .argument(name: "overwrite", type: .collection(["-y": .property(false)])),
            .argument(name: "output", type: .property(""), required: true),
        ]),
        ("Observe", [
            .argument(name: "when", type: .when(When(.distantPast))),
            .argument(name: "note", type: .property("")),
        ], []),
        ("Publish", [
            .argument(
                name: "visibility",
                type: .collection(["--visibility": .sequence([.property("public"), .property("unlisted"), .property("private")])]),
                default: .collection(["--visibility": .property("unlisted")])
            ),
        ], [
            .argument(name: "channels", type: .collection(["--channel": .sequence([.property("")])]), required: true),
            .argument(name: "visibility", type: .collection(["--visibility": .sequence([.property("public"), .property("unlisted"), .property("private")])])),
            .argument(name: "dryRun", type: .collection(["--dry-run": .property(false)])),
        ]),
        ("Empty", [], []),
    ]

    let parameters = harnesses.first { $0.name == selected }.map { Interface($0.command + $0.harness).parameters } ?? []

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
