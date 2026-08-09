import Foundation


enum Intent: Codable, Sendable {
    case compose(Composing)
    case dispatch(Dispatching)
    case observe(Observing)
    case execute(Executing)
    case traverse(Traversing)

    var key: Key {
        switch self {
            case .compose(let intent): return intent.key
            case .dispatch(let intent): return intent.key
            case .observe(let intent): return intent.key
            case .execute(let intent): return intent.key
            case .traverse(let intent): return intent.key
        }
    }

    var harness: Reference {
        switch self {
            case .compose(let intent): return intent.harness
            case .dispatch(let intent): return intent.harness
            case .observe(let intent): return intent.harness
            case .execute(let intent): return intent.harness
            case .traverse(let intent): return intent.harness
        }
    }

    var transcript: Reference {
        switch self {
            case .compose(let intent): return intent.transcript
            case .dispatch(let intent): return intent.transcript
            case .observe(let intent): return intent.transcript
            case .execute(let intent): return intent.transcript
            case .traverse(let intent): return intent.transcript
        }
    }

    var observing: Bool {
        if case .observe = self { true }
        else { false }
    }

    func start(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        switch self {
            case .compose(let intent): return try intent.compose(signal)
            case .dispatch(let intent): return try intent.dispatch(signal)
            case .observe(let intent): return try intent.observe(signal)
            case .execute(let intent): return try intent.execute(signal)
            case .traverse(let intent): return try intent.traverse(signal)
        }
    }
}

struct Composing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func compose(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        try start(harness, origin: origin, transcript: transcript, signal: signal)
        return nil
    }
}

struct Dispatching: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func dispatch(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        try start(harness, origin: origin, transcript: transcript, signal: signal)
        return nil
    }
}

struct Executing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func execute(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        try start(harness, origin: origin, transcript: transcript, signal: signal)
        return nil
    }
}

struct Observing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func observe(_ signal: @escaping (Signal) -> Void) throws -> Signal? { nil }
    func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? { nil }
}

struct Traversing: Contextual {
    let key: Key
    let origin: Reference
    let transcript: Reference
    let harness: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func traverse(_ signal: @escaping (Signal) -> Void) throws -> Signal? { .completed(nil) }
}

private func start(_ harness: Reference, origin: Reference, transcript: Reference, signal: @escaping (Signal) -> Void) throws {
    guard let result = try Harness.with(harness, { try $0.start(origin, transcript: transcript, output: signal) }) ?? nil
    else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
    if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
}

struct Context: Contextual {
    let key: Key
    let origin: Reference
    let transcript: Reference
    private(set) var intents: [Intent] = []

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = Self.transcript(for: origin)
    }

    var harness: Reference? { Self.harness(for: origin) }

    mutating func start(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        guard let harnessRef = harness, let harness = Harness.with(harnessRef, { $0 }) else { return }
        let focused = focusedTranscript()
        let branch = focused ?? Transcript.new("\(harness.intent) Transcript".capitalized, owner: origin)
        let intent = parse(harness, transcript: branch)
        Transcript.update(transcript) { $0.insert(.started(harnessRef)) }
        if focused == nil { Transcript.update(transcript) { $0.insert(branch, intent.key) } }
        recordEnvironment(in: branch)
        intents.append(intent)

        let receive: @Sendable (Signal) -> Void = { signal in
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal { terminal(signal, branch) }
            }
        }

        do {
            if let terminal = try intent.start(receive) { receive(terminal) }
        } catch {
            receive(.failed(.string(String(describing: error))))
        }
    }

    mutating func stop() {
        guard Runtime.shared.services.stop(context: origin.contextId) else { return }
        let active = intents
        for intent in active {
            let signal = Signal.stopped(intent.harness)
            Transcript.update(intent.transcript) { $0.insert(signal) }
            complete(signal, from: intent.transcript)
        }
    }

    mutating func complete(_ signal: Signal, from branch: Reference) {
        guard signal.terminal else { return }
        Transcript.update(transcript) { $0.insert(signal) }
        intents.removeAll { $0.transcript == branch }
    }

    static func harness(for origin: Reference) -> Reference? {
        if let harness = Space.with(origin, { $0.harness }) ?? nil, Harness.with(harness, { $0 }) != nil { return harness }
        if let harness = Workspace.with(origin, { $0.harness }), Harness.with(harness, { $0 }) != nil { return harness }
        return nil
    }

    static func new(_ origin: Reference) -> Context { Self(origin) }

    private func parse(_ harness: Harness, transcript: Reference) -> Intent {
        switch harness.intent {
            case .compose: return .compose(Composing(origin, harness: harness.ref, transcript: transcript))
            case .dispatch: return .dispatch(Dispatching(origin, harness: harness.ref, transcript: transcript))
            case .observe: return .observe(Observing(origin, harness: harness.ref, transcript: transcript))
            case .execute: return .execute(Executing(origin, harness: harness.ref, transcript: transcript))
            case .traverse: return .traverse(Traversing(origin, harness: harness.ref, transcript: transcript))
        }
    }

    private func recordEnvironment(in transcript: Reference) {
        guard let closureRef = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure }),
              let closure = Closure.with(closureRef, { $0 })
        else { return }

        var inputs = closure.scenes.filter { !$0.descriptor.tags.contains("input") }
        if closure.input.type == Scene.self { inputs.append(closure.input) }
        let artifacts = closure.artifacts.sorted {
            $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
        }
        Transcript.update(transcript) { $0.insert("artifacts", .sequence(artifacts.map(Value.reference))) }
        for input in inputs { Transcript.update(transcript) { $0.insert(input) } }

        let next = Scene.new(origin, input: true)
        Closure.update(closureRef) { $0.input = next }
    }

    private func focusedTranscript() -> Reference? {
        guard let closureRef = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure }),
              let input = Closure.with(closureRef, { $0.input }),
              let state = Scene.with(input, { Scene -> String? in
                  guard let block = Scene.blocks.last, case .text(_, let value) = block else { return nil }
                  return value
              }) ?? nil,
              let id = Properties.load(state)?["focused"]?.string.flatMap(UUID.init(uuidString:)),
              let focused = Catalog.shared.get(id),
              focused.type is Transcript.Type,
              focused != transcript,
              !intents.contains(where: { $0.transcript == focused }),
              Transcript.with(focused, { $0.owner == origin }) == true,
              ((Transcript.with(transcript, { $0 })?.output("artifacts")) != nil) == true
        else { return nil }
        return focused
    }

    private static func transcript(for origin: Reference) -> Reference {
        let roots = Runtime.shared.transcripts(for: origin).filter { ref in
            Transcript.with(ref) { transcript in
                transcript.entries.contains { entry in
                    guard case .event(_, .composed(let source), _) = entry else { return false }
                    return source == origin
                }
            } == true
        }
        if let root = roots.min(by: { $0.descriptor.created < $1.descriptor.created }) { return root }

        let root = Transcript.new(origin.descriptor.name, owner: origin)
        Transcript.update(root) { $0.insert(.composed(origin)) }
        return root
    }
}
