import AgencyRuntime
import Foundation

struct StaticCommandsAddon: CommandAddon {
    var commands: [AgencyCommand] {
        [
            command(["artifacts"], docs: .root("ARTIFACTS", summary: "List, inspect, and open runtime artifacts.", commands: [
                .init(term: "list:", description: "List artifacts currently persisted in the runtime library"),
                .init(term: "show:", description: "Inspect an artifact by name, UUID, or query"),
                .init(term: "open:", description: "Open an artifact URL with macOS `open`")
            ], examples: [
                "agency artifacts list",
                "agency artifacts list --search docs",
                "agency artifacts open \"OpenAI Platform Docs\""
            ])),
            command(["artifacts", "list"], docs: .leaf("ARTIFACTS / LIST", usage: "agency artifacts list [--search <query>]", summary: "List runtime artifacts.", flags: [
                .init(term: "--search", description: "Filter artifacts by name, description, tag, type, or id")
            ], examples: [
                "agency artifacts list --search docs"
            ]), handler: listArtifacts),
            command(["artifacts", "show"], docs: .leaf("ARTIFACTS / SHOW", usage: "agency artifacts show <artifact> [--id <uuid>] [--name <name>]", summary: "Inspect a runtime artifact.", flags: targetFlags, examples: [
                "agency artifacts show Developer",
                "agency artifacts show --id 733F4775-0FE3-4513-817E-20F131CF9D89"
            ]), handler: showArtifact),
            command(["artifacts", "open"], docs: .leaf("ARTIFACTS / OPEN", usage: "agency artifacts open <artifact> [--id <uuid>] [--name <name>]", summary: "Open a runtime artifact URL.", flags: targetFlags, examples: [
                "agency artifacts open Developer",
                "agency artifacts open \"OpenAI Platform Docs\""
            ]), handler: openArtifact),

            command(["commands"], docs: .root("COMMANDS", summary: "List, inspect, and run runtime commands.", commands: [
                .init(term: "list:", description: "List runtime commands"),
                .init(term: "show:", description: "Inspect a runtime command"),
                .init(term: "run:", description: "Run a command through the Agency harness process")
            ], examples: [
                "agency commands list",
                "agency commands show curl",
                "agency commands run curl --arg https://example.com"
            ])),
            command(["commands", "list"], docs: .leaf("COMMANDS / LIST", usage: "agency commands list [--search <query>]", summary: "List runnable runtime commands.", flags: [
                .init(term: "--search", description: "Filter commands by name, description, tag, executable, type, or id")
            ], examples: [
                "agency commands list --search curl"
            ]), handler: listCommands),
            command(["commands", "show"], docs: .leaf("COMMANDS / SHOW", usage: "agency commands show <command> [--id <uuid>] [--name <name>]", summary: "Inspect a runtime command, including executable artifacts.", flags: targetFlags, examples: [
                "agency commands show curl"
            ]), handler: showCommand),
            command(["commands", "run"], docs: .leaf("COMMANDS / RUN", usage: "agency commands run <command> [arguments...] [--arg <value> ...]", summary: "Run a runtime command.", flags: targetFlags + [
                .init(term: "--arg", description: "Append an argument; can be repeated")
            ], examples: [
                "agency commands run curl --arg https://example.com",
                "agency commands run \"GitHub API Fetch\" apple/swift"
            ]), handler: runCommand),

            command(["harness"], docs: .root("HARNESSES", summary: "List, inspect, and start runtime harness.", commands: [
                .init(term: "list:", description: "List harness currently persisted in the runtime library"),
                .init(term: "show:", description: "Inspect a harness and its composed entries"),
                .init(term: "start:", description: "Start a harness through the Agency harness process")
            ], examples: [
                "agency harness list",
                "agency harness show \"Codex Harness\"",
                "agency harness start \"Codex Harness\""
            ])),
            command(["harness", "list"], docs: .leaf("HARNESSES / LIST", usage: "agency harness list [--search <query>]", summary: "List runtime harness.", flags: [
                .init(term: "--search", description: "Filter harness by name, description, tag, type, or id")
            ], examples: [
                "agency harness list --search codex"
            ]), handler: listHarness),
            command(["harness", "show"], docs: .leaf("HARNESSES / SHOW", usage: "agency harness show <harness> [--id <uuid>] [--name <name>]", summary: "Inspect a runtime harness.", flags: targetFlags, examples: [
                "agency harness show \"Codex Harness\""
            ]), handler: showHarness),
            command(["harness", "start"], docs: .leaf("HARNESSES / START", usage: "agency harness start <harness> [arguments...] [--arg <value> ...]", summary: "Start a runtime harness.", flags: targetFlags + [
                .init(term: "--arg", description: "Append an argument; can be repeated")
            ], examples: [
                "agency harness start \"Codex Harness\"",
                "agency harness start \"GitHub Harness\" apple/swift"
            ]), handler: startHarness)
        ]
    }

    private var targetFlags: [DocumentationEntry] {
        [
            .init(term: "--id", description: "Resolve by reference id, storage id, descriptor id, or context id"),
            .init(term: "--name", description: "Resolve by descriptor name")
        ]
    }

    private func command(_ path: CommandPath, docs: CommandDocumentation, handler: CommandHandler? = nil) -> AgencyCommand {
        AgencyCommand(path: path, documentation: docs, handler: handler)
    }
}

private extension StaticCommandsAddon {
    func listArtifacts(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        return RuntimeConsole.renderList(title: "ARTIFACTS", rows: RuntimeConsole.rows(Artifact.self, search: context.invocation.options.value(for: "search")) { ref, artifact, descriptor in
            RuntimeConsole.Row(ref: ref, name: descriptor.name, type: artifact.kind.type, detail: descriptor.description)
        })
    }

    func showArtifact(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Artifact.self, context: context, label: "artifact")
        let artifact = try RuntimeConsole.require(ref, as: Artifact.self)
        let descriptor = Runtime.shared.get(ref)
        return RuntimeConsole.renderDetail(title: "ARTIFACT", ref: ref, descriptor: descriptor, fields: [
            ("artifact type", artifact.kind.type),
            ("url", artifact.kind.url?.absoluteString ?? "")
        ])
    }

    func openArtifact(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Artifact.self, context: context, label: "artifact")
        let artifact = try RuntimeConsole.require(ref, as: Artifact.self)
        guard let url = artifact.kind.url else { throw CommandError.execution("Artifact has no URL: \(Runtime.shared.get(ref).name)") }
        try RuntimeConsole.open(url)
        return "Opened \(Runtime.shared.get(ref).name)\n\(url.absoluteString)"
    }

    func listCommands(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        return RuntimeConsole.renderList(title: "COMMANDS", rows: RuntimeConsole.commandRows(search: context.invocation.options.value(for: "search")))
    }

    func showCommand(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Command.self, context: context, label: "command")
        return try RuntimeConsole.renderCommandDetail(ref)
    }

    func runCommand(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Command.self, context: context, label: "command")
        let arguments = RuntimeConsole.arguments(afterTargetIn: context)
        try await RuntimeConsole.dispatch(ref, arguments: arguments) { chunk in
            FileHandle.standardOutput.write(Data(chunk.utf8))
        }
        return ""
    }

    func listHarness(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        return RuntimeConsole.renderList(title: "HARNESSES", rows: RuntimeConsole.rows(Harness.self, search: context.invocation.options.value(for: "search")) { ref, harness, descriptor in
            RuntimeConsole.Row(ref: ref, name: descriptor.name, type: "harness", detail: descriptor.description)
        })
    }

    func showHarness(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Harness.self, context: context, label: "harness")
        let harness = try RuntimeConsole.require(ref, as: Harness.self)
        let descriptor = Runtime.shared.get(ref)
        return RuntimeConsole.renderDetail(title: "SERVICE", ref: ref, descriptor: descriptor, fields: [
            ("main", RuntimeConsole.describe(harness.command)),
            ("entries", harness.parameters.map(RuntimeConsole.describe).joined(separator: " "))
        ])
    }

    func startHarness(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Harness.self, context: context, label: "harness")
        let arguments = RuntimeConsole.arguments(afterTargetIn: context)
        try await RuntimeConsole.process(ref, arguments: arguments) { chunk in
            FileHandle.standardOutput.write(Data(chunk.utf8))
        }
        return ""
    }
}

private enum RuntimeConsole {
    struct Row {
        let ref: Reference
        let name: String
        let type: String
        let detail: String
    }

    static func load() async throws {
        do { try await Runtime.shared.load() }
        catch { throw CommandError.execution("Failed to load Agency runtime: \(error)") }
    }

    static func rows<T: Resolvable>(_ type: T.Type, search: String?, map: (Reference, T, Descriptor) -> Row) -> [Row] {
        Runtime.shared.all(as: type)
            .map { ref, value in (ref, value, Runtime.shared.get(ref)) }
            .sorted { lhs, rhs in lhs.2.name.localizedCaseInsensitiveCompare(rhs.2.name) == .orderedAscending }
            .map { entry in
                let row = map(entry.0, entry.1, entry.2)
                return (ref: entry.0, descriptor: entry.2, row: row)
            }
            .filter { matches(search, ref: $0.ref, descriptor: $0.descriptor) || matches(search, row: $0.row) }
            .map(\.row)
    }

    static func commandRows(search: String?) -> [Row] {
        Runtime.shared.all(as: Command.self)
            .map { ref, _ -> (ref: Reference, descriptor: Descriptor, row: Row) in
            let descriptor = Runtime.shared.get(ref)
            return (ref, descriptor, Row(ref: ref, name: descriptor.name, type: "command", detail: descriptor.description))
            }
            .sorted { lhs, rhs in lhs.descriptor.name.localizedCaseInsensitiveCompare(rhs.descriptor.name) == .orderedAscending }
            .filter { matches(search, ref: $0.ref, descriptor: $0.descriptor) || matches(search, row: $0.row) }
            .map(\.row)
    }

    static func resolve<T: Resolvable>(_ type: T.Type, context: CommandContext, label: String) throws -> Reference {
        let query = try targetQuery(context, label: label)
        let entries = Runtime.shared.all(as: type).map { ref, value in (ref, value, Runtime.shared.get(ref)) }

        if let id = UUID(uuidString: query) {
            if let exact = entries.first(where: { ref, _, _ in
                ref.id == id || ref.storageId == id || ref.descriptorId == id || ref.contextId == id
            }) {  return exact.0 }
        }

        let exactMatches = entries.filter { _, _, descriptor in descriptor.name.caseInsensitiveCompare(query) == .orderedSame }
        if exactMatches.count == 1 { return exactMatches[0].0 }

        let fuzzyMatches = entries.filter { ref, _, descriptor in matches(query, ref: ref, descriptor: descriptor) }
        if fuzzyMatches.count == 1 { return fuzzyMatches[0].0 }
        if fuzzyMatches.isEmpty { throw CommandError.notFound("No \(label) found for: \(query)") }

        let names = fuzzyMatches.prefix(8).map { Runtime.shared.get($0.0).name }.joined(separator: ", ")
        throw CommandError.execution("Ambiguous \(label): \(query). Matches: \(names)")
    }

    static func renderCommandDetail(_ ref: Reference) throws -> String {
        let command = try require(ref, as: Command.self)
        return renderDetail(title: "CONTROL", ref: ref, descriptor: Runtime.shared.get(ref), fields: [
            ("exec", describe(command.exec)),
            ("params", command.parameters.map(describe).joined(separator: " "))
        ])
    }

    static func dispatch(_ ref: Reference, arguments: [String], output: @escaping (String) -> Void) async throws {
        guard let composition = Runtime.shared.compose(.init(Runtime.shared.workspace, [.dispatch(ref, args: arguments)])) else {
            throw CommandError.execution("Runtime failed to compose dispatch request.")
        }
        guard case .dispatch(let transcript)? = composition.intention.last else {
            throw CommandError.execution("Runtime dispatch request did not produce a dispatch transcript.")
        }
        try await render(transcript, output: output)
    }

    static func process(_ ref: Reference, arguments: [String], output: @escaping (String) -> Void) async throws {
        guard let composition = Runtime.shared.compose(.init(Runtime.shared.workspace, [.process(ref, args: arguments)])) else {
            throw CommandError.execution("Runtime failed to compose process request.")
        }
        guard case .process(let transcript)? = composition.intention.last else {
            throw CommandError.execution("Runtime process request did not produce a process transcript.")
        }
        try await render(transcript, output: output)
    }

    static func render(_ transcript: Reference, output: @escaping (String) -> Void) async throws {
        var rendered = 0
        while true {
            let entries = Transcript.with(transcript, { $0.entries }) ?? []
            for entry in entries.dropFirst(rendered) {
                if case .event(let event, _, _) = entry, let text = event.provider?.text, !text.isEmpty {
                    output(text.hasSuffix("\n") ? text : "\(text)\n")
                }
            }
            rendered = entries.count
            if entries.contains(where: \.terminal) { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    static func require<T: Resolvable>(_ ref: Reference, as type: T.Type) throws -> T {
        guard let value = Runtime.shared.all(as: type).first(where: { $0.0 == ref })?.1 else {
            throw CommandError.notFound("Reference is not a \(String(describing: type)): \(ref.id)")
        }
        return value
    }

    static func targetQuery(_ context: CommandContext, label: String) throws -> String {
        if let id = context.invocation.options.value(for: "id"), !id.isEmpty { return id }
        if let name = context.invocation.options.value(for: "name"), !name.isEmpty { return name }
        guard let first = context.invocation.positionals.first, !first.isEmpty else {
            throw CommandError.missingArgument("Provide a \(label) name or pass `--id <uuid>`.")
        }
        return first
    }

    static func arguments(afterTargetIn context: CommandContext) -> [String] {
        Array(context.invocation.positionals.dropFirst()) + context.invocation.options.values(for: "arg")
    }

    static func matches(_ search: String?, ref: Reference, descriptor: Descriptor) -> Bool {
        guard let search = search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty else { return true }
        return matches(search, ref: ref, descriptor: descriptor)
    }

    static func matches(_ query: String, ref: Reference, descriptor: Descriptor) -> Bool {
        let normalized = query.lowercased()
        let tags = descriptor.tags.joined(separator: " ").lowercased()
        let type = ref.type.map { String(describing: $0).lowercased() } ?? ""
        return descriptor.name.lowercased().contains(normalized)
            || descriptor.description.lowercased().contains(normalized)
            || tags.contains(normalized)
            || type.contains(normalized)
            || ref.id.uuidString.lowercased().contains(normalized)
            || ref.storageId.uuidString.lowercased().contains(normalized)
            || ref.descriptorId.uuidString.lowercased().contains(normalized)
    }

    static func matches(_ search: String?, row: Row) -> Bool {
        guard let search = search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty else { return true }
        let normalized = search.lowercased()
        return row.name.lowercased().contains(normalized)
            || row.type.lowercased().contains(normalized)
            || row.detail.lowercased().contains(normalized)
    }

    static func renderList(title: String, rows: [Row]) -> String {
        guard !rows.isEmpty else { return "\(title)\n\nNo results." }
        let nameWidth = max(4, rows.map(\.name.count).max() ?? 4)
        let typeWidth = max(4, rows.map(\.type.count).max() ?? 4)
        var lines = [title, ""]
        for row in rows {
            let columns = "\(row.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \(row.type.padding(toLength: typeWidth, withPad: " ", startingAt: 0))"
            lines.append(row.detail.isEmpty ? columns : "\(columns)  \(row.detail)")
        }
        return lines.joined(separator: "\n")
    }

    static func renderDetail(title: String, ref: Reference, descriptor: Descriptor, fields: [(String, String)]) -> String {
        var lines = [
            title,
            "",
            "name: \(descriptor.name)",
            "id: \(ref.id.uuidString)",
            "storage: \(ref.storageId.uuidString)",
            "runtime type: \(ref.type.map { String(describing: $0) } ?? "Unknown")"
        ]

        if !descriptor.description.isEmpty { lines.append("description: \(descriptor.description)") }
        if !descriptor.tags.isEmpty { lines.append("tags: \(descriptor.tags.sorted().joined(separator: ", "))") }
        for (key, value) in fields where !value.isEmpty { lines.append("\(key): \(value)") }
        return lines.joined(separator: "\n")
    }

    static func describe(_ ref: Reference) -> String {
        let descriptor = Runtime.shared.get(ref)
        return descriptor.name.isEmpty ? ref.id.uuidString : descriptor.name
    }

    static func describe(_ param: Command.Parameter) -> String {
        switch param {
        case .artifact(let ref): return describe(ref)
        case .argument(let value): return value
        case .properties(let props): return props.render()
        }
    }

    static func describe(_ param: Harness.Parameter) -> String {
        switch param {
        case .artifact(let ref), .command(let ref): return describe(ref)
        case .argument(let value): return value
        }
    }

    static func open(_ url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.isFileURL ? url.path : url.absoluteString]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CommandError.execution("open exited with status \(process.terminationStatus)")
        }
    }
}

private extension CommandDocumentation {
    static func root(_ name: String, summary: String, commands: [DocumentationEntry], examples: [String]) -> CommandDocumentation {
        let path = [name.lowercased()]
        return CommandDocumentation(
            path: path,
            title: "AGENCY / \(name)",
            intro: [summary],
            usage: "agency \(path[0]) <command> [flags]",
            blocks: [
                .list(title: "AVAILABLE COMMANDS", entries: commands),
                .list(title: "FLAGS", entries: [
                    .init(term: "--help", description: "Show documentation for this command"),
                    .init(term: "--search", description: "Search documentation within this command")
                ]),
                .examples(examples)
            ]
        )
    }

    static func leaf(_ name: String, usage: String, summary: String, flags: [DocumentationEntry], examples: [String]) -> CommandDocumentation {
        CommandDocumentation(
            path: name.lowercased().split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) },
            title: "AGENCY / \(name)",
            intro: [summary],
            usage: usage,
            blocks: [
                .list(title: "FLAGS", entries: flags + [
                    .init(term: "--help", description: "Show documentation for this command")
                ]),
                .examples(examples)
            ]
        )
    }
}
