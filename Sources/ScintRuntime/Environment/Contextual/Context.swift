import Foundation


enum Intent: Codable, Sendable {
    case compose(Composing)
    case dispatch(Dispatching)
    case observe(Observing)
    case execute(Executing)
    case traverse(Traversing)

    var key: Key {
        switch self {
            case .compose(let intent): intent.key
            case .dispatch(let intent): intent.key
            case .observe(let intent): intent.key
            case .execute(let intent): intent.key
            case .traverse(let intent): intent.key
        }
    }

    var harness: Reference {
        switch self {
            case .compose(let intent): intent.harness
            case .dispatch(let intent): intent.harness
            case .observe(let intent): intent.harness
            case .execute(let intent): intent.harness
            case .traverse(let intent): intent.harness
        }
    }

    var transcript: Reference {
        switch self {
            case .compose(let intent): intent.transcript
            case .dispatch(let intent): intent.transcript
            case .observe(let intent): intent.transcript
            case .execute(let intent): intent.transcript
            case .traverse(let intent): intent.transcript
        }
    }

    var observing: Bool { if case .observe = self { true } else { false } }

    func start(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        switch self {
            case .compose(let intent): intent.compose(terminal)
            case .dispatch(let intent): intent.dispatch(terminal)
            case .observe(let intent): intent.observe(terminal)
            case .execute(let intent): intent.execute(terminal)
            case .traverse(let intent): intent.traverse(terminal)
        }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        switch self {
            case .compose(let intent): intent.stop(terminal)
            case .dispatch(let intent): intent.stop(terminal)
            case .observe(let intent): intent.stop(terminal)
            case .execute(let intent): intent.stop(terminal)
            case .traverse(let intent): intent.stop(terminal)
        }
    }
}


struct Composing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    func compose(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = receiver(terminal)
        do { try start(receive) }
        catch { receive(.failed(.string(String(describing: error)))) }
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        guard let command = Harness.with(harness, { $0.command }) else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        return { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }
    }
    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        receiver(terminal)(.stopped(harness))
    }
}


struct Dispatching: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    func dispatch(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = receiver(terminal)
        do { try start(receive) }
        catch { receive(.failed(.string(String(describing: error)))) }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        receiver(terminal)(.stopped(harness))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        guard let command = Harness.with(harness, { $0.command }) else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        return { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }
    }
}


struct Executing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    func execute(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = receiver(terminal)
        do { try start(receive) }
        catch { receive(.failed(.string(String(describing: error)))) }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        receiver(terminal)(.stopped(harness))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        guard let command = Harness.with(harness, { $0.command }) else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        return { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }
    }
}


struct Observing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    func observe(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = receiver(terminal)
        do { try start(receive) }
        catch { receive(.failed(.string(String(describing: error)))) }
    }

    func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? { nil }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        receiver(terminal)(.stopped(harness))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        guard let command = Harness.with(harness, { $0.command }) else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        return { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }
    }
}


struct Traversing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    func traverse(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = receiver(terminal)
        do { try start(receive) }
        catch { receive(.failed(.string(String(describing: error)))) }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        receiver(terminal)(.stopped(harness))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        guard let command = Harness.with(harness, { $0.command }) else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        return { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }
    }
}


struct Context: Contextual {
    let key: Key
    let origin: Reference
    let transcript: Reference
    private(set) var intents: [Intent] = []

    init(_ origin: Reference) {
        self = Self.new(origin)
    }

    private init(_ origin: Reference, transcript: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = transcript
    }

    var harness: Reference? {
        let reference = Space.with(origin, { $0.harness }) ?? Workspace.with(origin, { $0.harness })
        guard let reference,
              Library.shared.store(for: reference)?.store(for: reference)?.keys().contains(reference) == true
        else { return nil }
        return reference
    }

    mutating func start(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard let harness else { return }
        let branch = intentTranscript()

        Transcript.update(transcript) { root in
            root.insert(.started(origin))
            if !root.entries.contains(where: { if case .transcript(let ref, _) = $0 { ref == branch } else { false } }) {
                root.insert(branch, .context(branch))
            }
        }

        do {
            let config = Space.with(origin, { $0.config }) ?? Workspace.with(origin, { $0.config }) ?? [:]
            if case .string(let input)? = config["prompt"], !input.isEmpty {
                Transcript.update(branch) { $0.insert("input", .string(input)) }
            }

            let kind = Harness.with(harness, { $0.intent })
            let serialized = Serialization(origin: origin, branch: branch, intent: kind).rendered
            Transcript.update(branch) { $0.insert("context", .string(serialized)) }
            let arguments = try Parser.parse(origin, for: harness, prompt: serialized)
            guard let intent = intent(branch, arguments: arguments) else { return }
            intents.append(intent)
            intent.start(terminal)
        } catch {
            let signal = Signal.failed(.string(String(describing: error)))
            Transcript.update(branch) { $0.insert(signal) }
            terminal(signal, branch)
        }
    }

    mutating func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        for intent in intents { intent.stop(terminal) }
    }

    mutating func complete(_ signal: Signal, from branch: Reference) {
        guard signal.terminal else { return }
        Transcript.update(transcript) { $0.insert(signal) }
        intents.removeAll { $0.transcript == branch }
    }

    static func new(_ origin: Reference) -> Context {
        let roots = Space.with(origin, { $0.transcripts }) ?? Workspace.with(origin, { $0.transcripts }) ?? []
        if let transcript = roots.first(where: { reference in
            Transcript.with(reference) { transcript in
                transcript.entries.contains { entry in
                    if case .event(_, .composed(let source), _) = entry { source == origin } else { false }
                }
            } == true
        }) {
            return Self(origin, transcript: transcript)
        }

        let transcript = Transcript.new(origin.descriptor.name, owner: origin)
        Transcript.update(transcript) { $0.insert(.composed(origin)) }
        return Self(origin, transcript: transcript)
    }

    private func intent(_ transcript: Reference, arguments: [String]) -> Intent? {
        guard let harness, let kind = Harness.with(harness, { $0.intent }) else { return nil }
        switch kind {
            case .compose: return .compose(Composing(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .dispatch: return .dispatch(Dispatching(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .observe: return .observe(Observing(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .execute: return .execute(Executing(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .traverse: return .traverse(Traversing(origin, harness: harness, transcript: transcript, arguments: arguments))
        }
    }

    private func intentTranscript() -> Reference {
        if let value = Space.with(origin, { $0.config["transcript"] })
                ?? Workspace.with(origin, { $0.config["transcript"] }),
           case .reference(let focused) = value,
           focused != transcript,
           !intents.contains(where: { $0.transcript == focused }),
           (Space.with(origin, { $0.transcripts }) ?? Workspace.with(origin, { $0.transcripts }) ?? []).contains(focused) {
            return focused
        }
        let name = harness.flatMap { Harness.with($0, { "\($0.intent) Transcript".capitalized }) } ?? "Intent Transcript"

        // One branch per intent: turns accumulate in a single thread rather than
        // sprouting a new branch for every message.
        let branches = Transcript.with(transcript, { $0.entries })?.compactMap { entry -> Reference? in
            guard case .transcript(let ref, _) = entry else { return nil }
            return ref
        } ?? []
        if let existing = branches.first(where: { $0.descriptor.name == name }) { return existing }

        return Transcript.new(name, owner: transcript)
    }
}
