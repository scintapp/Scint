import Foundation


struct Context: Contextual {
    let key: Key
    let origin: Reference
    var transcript: Reference
    private(set) var intents: [Intent] = []

    enum Intent: Codable, Sendable {
        case compose(Composing)
        case dispatch(Dispatching)
        case observe(Observing)
        case evaluate(Evaluating)
        case search(Searching)


        var kind: Signal.Intent {
            switch self {
                case .compose: .composing
                case .dispatch: .dispatching
                case .observe: .observing
                case .evaluate: .evaluating
                case .search: .searching
            }
        }

        var key: Key {
            switch self {
                case .compose(let intent): intent.key
                case .dispatch(let intent): intent.key
                case .observe(let intent): intent.key
                case .evaluate(let intent): intent.key
                case .search(let intent): intent.key
            }
        }

        var ref: Reference {
            switch self {
                case .compose(let intent): intent.ref
                case .dispatch(let intent): intent.ref
                case .observe(let intent): intent.ref
                case .evaluate(let intent): intent.ref
                case .search(let intent): intent.ref
            }
        }

        var harness: Reference {
            switch self {
                case .compose(let intent): intent.harness
                case .dispatch(let intent): intent.harness
                case .observe(let intent): intent.harness
                case .evaluate(let intent): intent.harness
                case .search(let intent): intent.harness
            }
        }

        var transcript: Reference {
            switch self {
                case .compose(let intent): intent.transcript
                case .dispatch(let intent): intent.transcript
                case .observe(let intent): intent.transcript
                case .evaluate(let intent): intent.transcript
                case .search(let intent): intent.transcript
            }
        }

        var observing: Bool { if case .observe = self { true } else { false } }

        func start(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
            Trace.say("Intent", "starting — this run is a \(self)")
            switch self {
                case .compose(let intent): intent.compose(terminal)
                case .dispatch(let intent): intent.dispatch(terminal)
                case .observe(let intent): intent.observe(terminal)
                case .evaluate(let intent): intent.evaluate(terminal)
                case .search(let intent): intent.search(terminal)
            }
        }

        func stop() {
            Trace.say("Intent", "stopping a \(self)")
            switch self {
                case .compose(let intent): intent.stop()
                case .dispatch(let intent): intent.stop()
                case .observe(let intent): intent.stop()
                case .evaluate(let intent): intent.stop()
                case .search(let intent): intent.stop()
            }
        }
    }

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = origin
    }

    var harness: Reference? {
        origin.type == Space.self
        ? Space.with(origin, { $0 })?.harness
        : Workspace.with(origin, { $0.harness })
    }

    mutating func handle(_ signal: Signal) {
        switch signal {
            case .composed:
                guard let composed = compose() else { return }
                process(composed)

            case .started, .updated:
                update(signal)

            case .stopped:
                for intent in intents { intent.stop() }
                update(signal)
                intents.removeAll()
                Composer.shared.announce(origin, signal)

            case .completed, .failed:
                update(signal)
                intents.removeAll { $0.kind == signal.intent }
                Composer.shared.announce(origin, signal)
        }
    }

    private mutating func compose() -> (intent: Harness.Intent, branch: Reference, arguments: [String])? {
        guard let harnessRef = harness, let harness = Harness.with(harnessRef, { $0 }) else { return nil }
        let declared = harness.intent
        let branch = self.branch(named: "\(declared)".capitalized)
        let closure = (Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure }))!
        let input = Closure.with(closure, { $0.input })!
        let config = Space.with(origin, { $0.config }) ?? Workspace.with(origin, { $0.config }) ?? [:]

        update(.started(origin, declared.signal, .reference(origin)))
        let request = Material.update(input) { material -> String in
            material.clear()
            return material.dump()
        } ?? ""
        update(request, from: input)
        update(linking: branch)

        let values = Dictionary(uniqueKeysWithValues: config.map { ($0.key, $0.value) })
        let inputValue = Value.string(Renderer.evaluation(origin, transcript: transcript, input: request))
        let arguments: [String]

        do {
            arguments = harness.arguments(with: try harness.bind(values, input: inputValue))
        } catch {
            let signal = Signal.failed(harnessRef, declared.signal, .string(String(describing: error)))
            update(signal)
            Composer.shared.announce(origin, signal)
            return nil
        }

        return (declared, branch, arguments)
    }

    private mutating func process(_ composed: (intent: Harness.Intent, branch: Reference, arguments: [String])) {
        let harness = self.harness!
        let branch = composed.branch
        let arguments = composed.arguments

        let intent: Self.Intent = switch composed.intent {
            case .compose: .compose(Composing(origin, harness: harness, transcript: branch, arguments: arguments))
            case .dispatch: .dispatch(Dispatching(origin, harness: harness, transcript: branch, arguments: arguments))
            case .evaluate: .evaluate(Evaluating(origin, harness: harness, transcript: branch, arguments: arguments))
            case .observe: .observe(Observing(origin, harness: harness, transcript: branch, arguments: arguments))
            case .search: .search(Searching(origin, harness: harness, transcript: branch, arguments: arguments))
        }

        intents.append(intent)
        let origin = self.origin
        intent.start { signal, _ in Context.update(origin) { $0.handle(signal) } }
    }

    private func update(_ signal: Signal) {
        Transcript.update(transcript) { $0.insert(signal) }
    }

    private func update(_ request: String, from source: Reference) {
        Transcript.update(transcript) { $0.insert(Chunk(transcript, source, .string(request))) }
    }

    private func update(linking branch: Reference) {
        Transcript.update(transcript) { root in
            if !root.branches.contains(branch) { root.insert(branch) }
        }
    }

    private func branch(named name: String) -> Reference {
        let branches = Transcript.with(transcript, { $0.branches }) ?? []
        return branches.first { $0.descriptor.name == name } ?? Transcript.new(name, owner: transcript)
    }

    static func new(_ origin: Reference) -> Context {
        let roots = Space.with(origin, { $0.transcripts }) ?? Workspace.with(origin, { $0.transcripts }) ?? []
        let existing = roots.first { reference in
            Transcript.with(reference) { transcript in
                transcript.entries.contains { entry in
                    guard case .event(.composed(let source), _) = entry else { return false }
                    return source == origin
                }
            } == true
        }

        var context = Self(origin)
        if let existing { context.transcript = existing }
        else {
            let transcript = Transcript.new(origin.descriptor.name, owner: origin)
            Transcript.update(transcript) { $0.insert(.composed(origin)) }
            context.transcript = transcript
        }
        return context
    }
}


extension Context {
    static func with<R>(_ ref: Reference, _ body: (Context) throws -> R) rethrows -> R? {
        try Composer.shared.context(ref).map(body)
    }

    @discardableResult
    static func update<R>(_ ref: Reference, _ body: (inout Context) throws -> R) rethrows -> R? {
        try Composer.shared.update(ref, body)
    }
}
