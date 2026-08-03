import Foundation


public struct Composing: Contextual {
    public let key: Key
    public let origin: Reference
    public var harness: Reference
    public var transcript: Reference

    public init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    func compose(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        try start(harness, origin: origin, values: values, signal: signal)
        return nil
    }
}

public struct Dispatching: Contextual {
    public let key: Key
    public let origin: Reference
    public var transcript: Reference
    public var harness: Reference?
    public var commands: [Reference]

    public init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.transcript = origin
        self.harness = nil
        self.commands = []
    }

    func dispatch(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        if let harness { try start(harness, origin: origin, values: values, signal: signal); return nil }
        for command in commands {
            guard let result = try Command.with(command, { command in
                let parsed = try Parser.parse(values, parameters: command.parameters)
                return command.dispatch(parsed, output: signal)
            }) ?? nil else {
                throw RuntimeError.context(.startFailed("Command dispatch returned no result."))
            }
            if let error = result.error { throw RuntimeError.context(.startFailed(error)) }
        }
        return commands.isEmpty ? .completed : nil
    }
}

public struct Observing: Contextual {
    public let key: Key
    public let origin: Reference
    public var transcript: Reference
    public var harness: Reference
    public var action: Reference
    public var target: Reference?
    var reaction: Bool

    public init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.action = origin
        self.target = nil
        self.reaction = false
    }

    func observe(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        if values["operation"] == .collection(["--operation": .string("remove")]) {
            try start(harness, origin: origin, values: values, signal: signal)
            return nil
        }

        let context = Runtime.shared.context(from: origin)
        guard context.contains(action), action != origin else { throw RuntimeError.context(.missingRequired(action)) }
        if let target, !context.contains(target) { throw RuntimeError.context(.missingRequired(target)) }
        if reaction { return try react(signal) }
        if values["schedule"] == nil {
            guard target != nil else { throw RuntimeError.context(.invalidArguments("Observer requires a schedule or target.")) }
            return .completed
        }

        let behavior: String
        switch action.type {
            case is Artifact.Type:
                guard (Artifact.with(action, { $0.handler.executable }) ?? nil) != nil else {
                    throw RuntimeError.context(.invalidArguments("Observer action Artifact is not runnable."))
                }
                behavior = "run"
            case is Command.Type: behavior = "dispatch"
            case is Space.Type, is Workspace.Type: behavior = "trigger"
            default: throw RuntimeError.context(.missingRequired(action))
        }

        var environment = [
            "Scint_ACTION": behavior,
            "Scint_ACTION_REF": action.descriptorId.uuidString.lowercased()
        ]
        if let target { environment["Scint_TARGET"] = target.descriptorId.uuidString.lowercased() }
        try start(harness, origin: origin, values: values, environment: environment, signal: signal)
        return nil
    }

    private func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        let input = target.map { [Value.reference($0)] } ?? []
        switch action.type {
            case is Artifact.Type:
                let environment = target.map { ["Scint_TARGET": $0.descriptorId.uuidString.lowercased()] } ?? [:]
                guard let executable = Artifact.with(action, { $0.handler.executable }) ?? nil,
                      let result = Runtime.shared.services.start(executable, environment: environment)
                else { throw RuntimeError.context(.startFailed("Artifact action returned no result.")) }
                if let error = result.error { throw RuntimeError.context(.startFailed(error)) }
                Runtime.shared.services.output(pid: result.pid, signal)
                return nil
            case is Command.Type:
                guard let result = try Command.with(action) { command in
                    command.dispatch(try Parser.parse(input, parameters: command.parameters), output: signal)
                } ?? nil else { throw RuntimeError.context(.startFailed("Command action returned no result.")) }
                if let error = result.error { throw RuntimeError.context(.startFailed(error)) }
                return nil
            case is Space.Type, is Workspace.Type:
                guard Runtime.shared.eval(action) != nil else { throw RuntimeError.context(.startFailed("Process action could not compose.")) }
                return .completed
            default:
                throw RuntimeError.context(.missingRequired(action))
        }
    }
}

public struct Executing: Contextual {
    public let key: Key
    public let origin: Reference
    public var harness: Reference
    public var transcript: Reference

    public init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    func execute(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        try start(harness, origin: origin, values: values, signal: signal)
        return nil
    }
}

public struct Traversing: Contextual {
    public let key: Key
    public let origin: Reference
    public var transcript: Reference
    public var harness: Reference
    public var route: Route

    public struct Route: Codable, Sendable, Equatable {
        public var objective: Reference?
        public var visited: [Reference]
        public var next: [Reference]
    }

    public init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.route = .init(objective: origin, visited: [], next: [])
    }

    func traverse(_: [String: Value], signal _: @escaping (Signal) -> Void) throws -> Signal? { .completed }
}

private func start(_ harness: Reference, origin: Reference, values: [String: Value], environment: [String: String] = [:], signal: @escaping (Signal) -> Void) throws {
    let environment = environment.merging(["Scint_CONTEXT": origin.contextId.uuidString.lowercased()]) { current, _ in current }
    guard let result = Harness.with(harness, { $0.run(values, environment: environment, output: signal) }) ?? nil else {
        throw RuntimeError.context(.startFailed("Harness start returned no result."))
    }
    if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
}
