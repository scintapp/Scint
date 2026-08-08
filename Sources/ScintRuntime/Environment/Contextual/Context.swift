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

    var pid: Int32? {
        switch self {
            case .compose(let intent): return intent.pid
            case .dispatch(let intent): return intent.pid
            case .execute(let intent): return intent.pid
            case .observe, .traverse: return nil
        }
    }

    mutating func start(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        switch self {
            case .compose(var intent):
                let terminal = try intent.compose(signal)
                self = .compose(intent)
                return terminal

            case .dispatch(var intent):
                let terminal = try intent.dispatch(signal)
                self = .dispatch(intent)
                return terminal

            case .observe(let intent):
                return try intent.observe(signal)

            case .execute(var intent):
                let terminal = try intent.execute(signal)
                self = .execute(intent)
                return terminal

            case .traverse(let intent):
                return try intent.traverse(signal)
        }
    }

    func stop() -> Bool {
        guard let pid else { return true }
        return Harness.with(harness) { $0.stop(pid: pid) } ?? false
    }
}

struct Composing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    var pid: Int32?

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.pid = nil
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.pid = nil
    }

    mutating func compose(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = try Harness.with(harness, {
            try $0.start(origin, transcript: transcript, output: signal) }) ?? nil else {
            throw RuntimeError.Context.startFailed("Harness start returned no result.")
        }
        if let error = result.error, !error.isEmpty { throw RuntimeError.Context.startFailed(error) }
        pid = result.pid
        return nil
    }
}

struct Dispatching: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    var pid: Int32?

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.pid = nil
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.pid = nil
    }

    mutating func dispatch(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = try Harness.with(harness, { try $0.start(origin, transcript: transcript, output: signal) }) ?? nil
        else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
        pid = result.pid
        return nil
    }
}

struct Executing: Contextual {
    let key: Key
    let origin: Reference
    let harness: Reference
    let transcript: Reference
    var pid: Int32?

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
        self.pid = nil
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(transcript)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
        self.pid = nil
    }

    mutating func execute(_ signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = try Harness.with(harness, { try $0.start(origin, transcript: transcript, output: signal) }) ?? nil
        else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
        pid = result.pid
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

    mutating func start() {
        guard let harnessRef = harness, let harness = Harness.with(harnessRef, { $0 }) else { return }
        let focused = focusedTranscript()
        let branch = focused ?? Transcript.new("\(harness.intent) Transcript".capitalized, owner: origin)
        let intent = parse(harness, transcript: branch)
        if focused == nil { Transcript.update(transcript) { $0.insert(branch, intent.key) } }
        recordEnvironment(in: branch)
        Transcript.update(branch) { $0.insert(.started(harnessRef)) }
        intents.append(intent)

        let origin = self.origin
        let receive: @Sendable (Signal) -> Void = { signal in
            Task { @MainActor in
                Composer.shared.receive(signal, origin: origin, transcript: branch)
            }
        }

        do {
            let index = intents.index(before: intents.endIndex)
            if let terminal = try intents[index].start(receive) {
                self.receive(terminal, from: branch)
            }
        } catch {
            self.receive(.failed(.string(String(describing: error))), from: branch)
        }
    }

    mutating func stop() {
        let active = intents
        for intent in active where intent.stop() {
            receive(.stopped(intent.harness), from: intent.transcript)
        }
    }

    mutating func receive(_ signal: Signal, from branch: Reference) {
        Transcript.update(branch) { $0.insert(signal) }
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
