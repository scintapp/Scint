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

            command(["controls"], docs: .root("CONTROLS", summary: "List, inspect, and run runtime controls.", commands: [
                .init(term: "list:", description: "List runnable controls, including executable artifacts and registered controls"),
                .init(term: "show:", description: "Inspect an executable artifact or registered control"),
                .init(term: "run:", description: "Run a control through the Agency service process")
            ], examples: [
                "agency controls list",
                "agency controls show curl",
                "agency controls run curl --arg https://example.com"
            ])),
            command(["controls", "list"], docs: .leaf("CONTROLS / LIST", usage: "agency controls list [--search <query>]", summary: "List runnable runtime controls.", flags: [
                .init(term: "--search", description: "Filter controls by name, description, tag, executable, type, or id")
            ], examples: [
                "agency controls list --search curl"
            ]), handler: listCommands),
            command(["controls", "show"], docs: .leaf("CONTROLS / SHOW", usage: "agency controls show <control> [--id <uuid>] [--name <name>]", summary: "Inspect a runtime control, including executable artifacts.", flags: targetFlags, examples: [
                "agency controls show curl"
            ]), handler: showCommand),
            command(["controls", "run"], docs: .leaf("CONTROLS / RUN", usage: "agency controls run <control> [arguments...] [--arg <value> ...]", summary: "Run a runtime control.", flags: targetFlags + [
                .init(term: "--arg", description: "Append an argument; can be repeated")
            ], examples: [
                "agency controls run curl --arg https://example.com",
                "agency controls run \"GitHub API Fetch\" apple/swift"
            ]), handler: runCommand),

            command(["services"], docs: .root("SERVICES", summary: "List, inspect, and start runtime services.", commands: [
                .init(term: "list:", description: "List services currently persisted in the runtime library"),
                .init(term: "show:", description: "Inspect a service and its composed entries"),
                .init(term: "start:", description: "Start a service through the Agency service process")
            ], examples: [
                "agency services list",
                "agency services show \"Codex Harness\"",
                "agency services start \"Codex Harness\""
            ])),
            command(["services", "list"], docs: .leaf("SERVICES / LIST", usage: "agency services list [--search <query>]", summary: "List runtime services.", flags: [
                .init(term: "--search", description: "Filter services by name, description, tag, type, or id")
            ], examples: [
                "agency services list --search codex"
            ]), handler: listHarnesss),
            command(["services", "show"], docs: .leaf("SERVICES / SHOW", usage: "agency services show <service> [--id <uuid>] [--name <name>]", summary: "Inspect a runtime service.", flags: targetFlags, examples: [
                "agency services show \"Codex Harness\""
            ]), handler: showHarness),
            command(["services", "start"], docs: .leaf("SERVICES / START", usage: "agency services start <service> [arguments...] [--arg <value> ...]", summary: "Start a runtime service.", flags: targetFlags + [
                .init(term: "--arg", description: "Append an argument; can be repeated")
            ], examples: [
                "agency services start \"Codex Harness\"",
                "agency services start \"GitHub Harness\" apple/swift"
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
            RuntimeConsole.Row(ref: ref, name: descriptor.name, type: artifact.entry.type, detail: descriptor.description)
        })
    }

    func showArtifact(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Artifact.self, context: context, label: "artifact")
        let artifact = try RuntimeConsole.require(ref, as: Artifact.self)
        let descriptor = Runtime.shared.get(ref)
        return RuntimeConsole.renderDetail(title: "ARTIFACT", ref: ref, descriptor: descriptor, fields: [
            ("artifact type", artifact.entry.type),
            ("url", artifact.entry.url?.absoluteString ?? "")
        ])
    }

    func openArtifact(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Artifact.self, context: context, label: "artifact")
        let artifact = try RuntimeConsole.require(ref, as: Artifact.self)
        guard let url = artifact.entry.url else {
            throw CommandError.execution("Artifact has no URL: \(Runtime.shared.get(ref).name)")
        }
        try RuntimeConsole.open(url)
        return "Opened \(Runtime.shared.get(ref).name)\n\(url.absoluteString)"
    }

    func listCommands(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        return RuntimeConsole.renderList(title: "CONTROLS", rows: RuntimeConsole.controlRows(search: context.invocation.options.value(for: "search")))
    }

    func showCommand(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let target = try RuntimeConsole.resolveCommandTarget(context: context)
        return try RuntimeConsole.renderCommandDetail(target)
    }

    func runCommand(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let target = try RuntimeConsole.resolveCommandTarget(context: context)
        let arguments = RuntimeConsole.arguments(afterTargetIn: context)
        let status = try RuntimeConsole.dispatchAndWait(target, arguments: arguments) { chunk in
            FileHandle.standardOutput.write(Data(chunk.utf8))
        }
        guard status == 0 else { throw CommandError.processExited(status) }
        return ""
    }

    func listHarnesss(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        return RuntimeConsole.renderList(title: "SERVICES", rows: RuntimeConsole.rows(Harness.self, search: context.invocation.options.value(for: "search")) { ref, service, descriptor in
            RuntimeConsole.Row(ref: ref, name: descriptor.name, type: "service", detail: descriptor.description)
        })
    }

    func showHarness(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Harness.self, context: context, label: "service")
        let service = try RuntimeConsole.require(ref, as: Harness.self)
        let descriptor = Runtime.shared.get(ref)
        return RuntimeConsole.renderDetail(title: "SERVICE", ref: ref, descriptor: descriptor, fields: [
            ("main", RuntimeConsole.describe(service.command)),
            ("entries", service.parameters.map(RuntimeConsole.describe).joined(separator: " "))
        ])
    }

    func startHarness(_ context: CommandContext) async throws -> String {
        try await RuntimeConsole.load()
        let ref = try RuntimeConsole.resolve(Harness.self, context: context, label: "service")
        let arguments = RuntimeConsole.arguments(afterTargetIn: context)
        let status = try RuntimeConsole.startAndWait(ref, arguments: arguments) { chunk in
            FileHandle.standardOutput.write(Data(chunk.utf8))
        }
        guard status == 0 else { throw CommandError.processExited(status) }
        return ""
    }
}

private enum RuntimeConsole {
    typealias ProcessStart = (pid: Int32, error: String?)

    enum CommandTarget {
        case registered(Reference)
        case executable(Reference)

        var ref: Reference {
            switch self {
            case .registered(let ref), .executable(let ref): return ref
            }
        }
    }

    struct Row {
        let ref: Reference
        let name: String
        let type: String
        let detail: String
    }

    static func load() async throws {
        do {
            try await Runtime.shared.load()
        } catch {
            throw CommandError.execution("Failed to load Agency runtime: \(error)")
        }
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

    static func controlRows(search: String?) -> [Row] {
        let executableRows = Runtime.shared.all(as: Artifact.self).compactMap { ref, artifact -> (ref: Reference, descriptor: Descriptor, row: Row)? in
            guard artifact.entry.isExecutable else { return nil }
            let descriptor = Runtime.shared.get(ref)
            return (ref, descriptor, Row(ref: ref, name: descriptor.name, type: "control", detail: descriptor.description))
        }

        let registeredRows = Runtime.shared.all(as: Command.self).map { ref, control -> (ref: Reference, descriptor: Descriptor, row: Row) in
            let descriptor = Runtime.shared.get(ref)
            return (ref, descriptor, Row(ref: ref, name: descriptor.name, type: "control", detail: descriptor.description))
        }

        return (executableRows + registeredRows)
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
            }) {
                return exact.0
            }
        }

        let exactMatches = entries.filter { _, _, descriptor in descriptor.name.caseInsensitiveCompare(query) == .orderedSame }
        if exactMatches.count == 1 { return exactMatches[0].0 }

        let fuzzyMatches = entries.filter { ref, _, descriptor in matches(query, ref: ref, descriptor: descriptor) }
        if fuzzyMatches.count == 1 { return fuzzyMatches[0].0 }
        if fuzzyMatches.isEmpty { throw CommandError.notFound("No \(label) found for: \(query)") }

        let names = fuzzyMatches.prefix(8).map { Runtime.shared.get($0.0).name }.joined(separator: ", ")
        throw CommandError.execution("Ambiguous \(label): \(query). Matches: \(names)")
    }

    static func resolveCommandTarget(context: CommandContext) throws -> CommandTarget {
        let query = try targetQuery(context, label: "control")
        let registered = Runtime.shared.all(as: Command.self).map { ref, _ in
            (target: CommandTarget.registered(ref), descriptor: Runtime.shared.get(ref))
        }
        let executable = Runtime.shared.all(as: Artifact.self).compactMap { ref, artifact -> (target: CommandTarget, descriptor: Descriptor)? in
            guard artifact.entry.isExecutable else { return nil }
            return (.executable(ref), Runtime.shared.get(ref))
        }
        let entries = registered + executable

        if let id = UUID(uuidString: query) {
            if let exact = entries.first(where: { entry in
                let ref = entry.target.ref
                return ref.id == id || ref.storageId == id || ref.descriptorId == id || ref.contextId == id
            }) {
                return exact.target
            }
        }

        let exactMatches = entries.filter { $0.descriptor.name.caseInsensitiveCompare(query) == .orderedSame }
        if exactMatches.count == 1 { return exactMatches[0].target }

        let fuzzyMatches = entries.filter { matches(query, ref: $0.target.ref, descriptor: $0.descriptor) }
        if fuzzyMatches.count == 1 { return fuzzyMatches[0].target }
        if fuzzyMatches.isEmpty { throw CommandError.notFound("No control found for: \(query)") }

        let names = fuzzyMatches.prefix(8).map { $0.descriptor.name }.joined(separator: ", ")
        throw CommandError.execution("Ambiguous control: \(query). Matches: \(names)")
    }

    static func renderCommandDetail(_ target: CommandTarget) throws -> String {
        switch target {
        case .registered(let ref):
            let control = try require(ref, as: Command.self)
            return renderDetail(title: "CONTROL", ref: ref, descriptor: Runtime.shared.get(ref), fields: [
                ("control source", "registered"),
                ("exec", describe(control.exec)),
                ("params", control.parameters.map(describe).joined(separator: " "))
            ])
        case .executable(let ref):
            let artifact = try require(ref, as: Artifact.self)
            let executable = artifact.entry.executable ?? artifact.entry.url?.absoluteString ?? ""
            return renderDetail(title: "CONTROL", ref: ref, descriptor: Runtime.shared.get(ref), fields: [
                ("control source", "executable artifact"),
                ("exec", executable)
            ])
        }
    }

    static func dispatchAndWait(_ target: CommandTarget, arguments: [String], output: @escaping (String) -> Void) throws -> Int32 {
        switch target {
        case .registered(let ref):
            return try waitForProcess(output: output) { stream in
                Command.with(ref) { control -> ProcessStart? in
                    control.dispatch(arguments, output: stream)
                } ?? nil
            }
        case .executable(let ref):
            return try waitForProcess(output: output) { stream in
                Artifact.with(ref) { artifact -> ProcessStart? in
                    guard artifact.entry.isExecutable else { return nil }
                    var control = Command()
                    control.exec = ref
                    return control.dispatch(arguments, output: stream)
                } ?? nil
            }
        }
    }

    static func startAndWait(_ ref: Reference, arguments: [String], output: @escaping (String) -> Void) throws -> Int32 {
        try waitForProcess(output: output) { stream in
            Harness.with(ref) { service -> ProcessStart? in
                service.start(arguments, output: stream)
            } ?? nil
        }
    }

    static func waitForProcess(
        output: @escaping (String) -> Void,
        start: (@escaping (String) -> Void) -> (pid: Int32, error: String?)?
    ) throws -> Int32 {
        let done = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var exitCode: Int32?

        let result = start { chunk in
            if let status = terminationStatus(from: chunk) {
                lock.withLock { exitCode = status }
                done.signal()
                return
            }
            output(chunk)
        }

        guard let result else {
            throw CommandError.execution("Process start returned no result.")
        }
        if let error = result.error, !error.isEmpty {
            throw CommandError.execution(error)
        }

        done.wait()
        return lock.withLock { exitCode ?? 1 }
    }

    static func terminationStatus(from chunk: String) -> Int32? {
        for line in chunk.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["event"] as? String == "terminated"
            else { continue }

            if let code = object["exitCode"] as? Int { return Int32(code) }
            if let code = object["exitCode"] as? Int32 { return code }
        }
        return nil
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

        if !descriptor.description.isEmpty {
            lines.append("description: \(descriptor.description)")
        }
        if !descriptor.tags.isEmpty {
            lines.append("tags: \(descriptor.tags.sorted().joined(separator: ", "))")
        }
        for (key, value) in fields where !value.isEmpty {
            lines.append("\(key): \(value)")
        }
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
        }
    }

    static func describe(_ param: Harness.Parameter) -> String {
        switch param {
        case .artifact(let ref), .control(let ref): return describe(ref)
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
