import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct Argument: Identifiable {
    let name: String
    let schema: Schema

    var id: String { name }
    var required: Bool { schema.required }
    var resting: Value? { schema.fallback }
    var placeholder: String { resting.map { "Default (\($0.title))" } ?? (required ? "Required" : "Default") }
    var label: String { Self.label(name) }

    static func clock(_ key: String) -> Bool { key.lowercased().contains("time") }

    static func symbol(_ key: String) -> String {
        label(key).lowercased().split(separator: " ").reversed().lazy.compactMap { word -> String? in
            switch true {
                case word.hasPrefix("dir"), word.hasPrefix("folder"), word.hasPrefix("path"): "folder"
                case word.hasPrefix("timeout"), word.hasPrefix("interval"), word.hasPrefix("latency"): "timer"
                case word.hasPrefix("time"): "clock"
                case word.hasPrefix("model"): "cpu"
                case word.hasPrefix("effort"): "lightbulb.max"
                case word.hasPrefix("sandbox"), word.hasPrefix("permission"): "lock.shield"
                case word.hasPrefix("command"), word == "action": "switch.2"
                case word.hasPrefix("target"), word.hasPrefix("space"): "target"
                case word.hasPrefix("schedule"), word.hasPrefix("date"), word == "at", word == "when": "calendar"
                case word.hasPrefix("repeat"), word.hasPrefix("every"): "repeat"
                case word.hasPrefix("url"), word.hasPrefix("endpoint"): "link"
                case word.hasPrefix("event"): "bolt"
                case word.hasPrefix("label"), word.hasPrefix("name"): "tag"
                case word.hasPrefix("check"), word.hasPrefix("query"): "magnifyingglass"
                default: nil
            }
        }.first ?? "slider.horizontal.3"
    }

    static func label(_ text: String) -> String {
        text.reduce(into: "") { label, character in
            if character == "-" || character == "_" { label.append(" ") }
            else {
                if character.isUppercase, !label.isEmpty { label.append(" ") }
                label.append(character)
            }
        }.capitalized
    }

    init(name: String, schema: Schema) {
        self.name = name
        self.schema = schema
    }

    init(_ input: (name: String, schema: Schema)) {
        self.init(name: input.name, schema: input.schema)
    }

    func accepts(_ value: Value) -> Bool { (try? schema.construct(value, name: name)) != nil }

    static func inputs(of owner: Reference, values: [String: Value] = [:]) -> [(name: String, schema: Schema)] {
        if let inputs = Command.with(owner, { $0.parameters.inputs(values) }) { return inputs }
        guard let harness = Interface.with(owner, { $0 }), let slot = harness.signatures[.start] else { return [] }
        return ([slot] + harness.parameters).inputs(values)
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
        HStack {
            configuration.label
            Spacer(minLength: 12)
            configuration.content
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

    var value: Value? { configuration.value.wrappedValue }
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
        let content = TermField(argument.schema, value: accepted, placeholder: argument.placeholder, resting: argument.resting)
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

    var inputs: [(name: String, schema: Schema)] { Argument.inputs(of: owner) }

    var input: Reference? { Space.with(space, { $0.input }) }
    var values: [String: Value] { input.flatMap { Document.with($0, { $0.values(owner) }) } ?? [:] }

    func store(_ values: [String: Value]) {
        guard let input else { return }
        Document.update(input) { $0.metadata(values.isEmpty ? nil : .collection(values), for: owner) }
    }
}

struct Arguments: View {
    let inputs: [(name: String, schema: Schema)]
    @Binding var values: [String: Value]

    init(_ inputs: [(name: String, schema: Schema)], values: Binding<[String: Value]>) {
        self.inputs = inputs
        self._values = values
    }

    init(for owner: Reference?, values: Binding<[String: Value]>) {
        self.init(owner.map { Argument.inputs(of: $0, values: values.wrappedValue) } ?? [], values: values)
    }

    var arguments: [Argument] { inputs.map(Argument.init) }

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
        func words(_ argument: ScintRuntime.Argument) -> [String] {
            switch argument {
                case .literal(let text): [text]
                case .reference(let ref), .command(let ref, _): ["‹\(ref.descriptor.name)›"]
                case .joined(let parts), .shell(let parts): [parts.flatMap(words).joined()]
            }
        }

        return parameters.flatMap { parameter -> [(text: String, literal: Bool)] in
            guard let arguments = try? parameter.arguments(values)
            else { return parameter.inputs.map { ("‹\($0.name)›", false) } }
            return arguments.flatMap(words).map { ($0, parameter.inputs.isEmpty) }
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

    let sandbox: [Schema] = [.string("read-only"), .string("workspace-write"), .string("danger-full-access")]

    let harnesses: [(name: String, harness: [Parameter], command: [Parameter])] = [
        ("Agent", [
            .flag("--sandbox", .options([.default(.string("read-only"))] + sandbox.dropFirst())),
            .subcommand("input", .required(.string)),
            .flag("--brief", .string),
        ], [
            .subcommand("exec"),
            .flag("--model", .options([.string("gpt-6-astra"), .string("gpt-5.5")])),
            .flag("--config", .dictionary(["model_reasoning_effort": .range([.string("low"), .string("medium"), .string("high"), .string("xhigh")])])),
            .flag("--sandbox", .options([sandbox[0], .default(sandbox[1]), sandbox[2]])),
            .flag("--max-turns", .integer),
            .subcommand("input", .string),
        ]),
        ("Transcode", [], [
            .flag("--format", .required(.options([.string("mp4"), .string("mov"), .string("webm")]))),
            .flag("--quality", .range([.string("draft"), .default(.string("good")), .string("best")])),
            .flag("--bitrate", .integer),
            .flag("--trim", .dictionary(["start": .decimal, "end": .decimal])),
            .switch("-y", .bool),
            .subcommand("output", .required(.string)),
        ]),
        ("Observe", [
            .flag("--date", .date),
            .flag("--repeat", .options(When.Repeat.allCases.map { .string($0.rawValue) })),
            .flag("--note", .string),
        ], []),
        ("Publish", [
            .flag("--visibility", .options([.string("public"), .default(.string("unlisted")), .string("private")])),
        ], [
            .flag("--channel", .required(.list(.string)), as: "channels"),
            .flag("--visibility", .options([.string("public"), .string("unlisted"), .string("private")])),
            .switch("--dry-run", .bool),
        ]),
        ("Empty", [], []),
    ]

    let parameters = harnesses.first { $0.name == selected }.map { $0.command.overlaid(by: $0.harness) } ?? []

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
                    Arguments(parameters.inputs(), values: draft)

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
                Arguments(parameters.inputs(), values: $values)
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
