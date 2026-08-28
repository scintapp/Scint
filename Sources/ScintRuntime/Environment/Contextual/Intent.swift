import Foundation


// MARK: - Intent
// With the exception of `Executing`, intents are mostly stubs and scaffold. Each intent diverges here; the
// identical implementations are merely sketches, not accidental duplication.


enum Intent: Codable, Sendable {
    case compose(Composing)
    case dispatch(Dispatching)
    case observe(Observing)
    case evaluate(Evaluating)
    case search(Searching)


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

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        Trace.say("Intent", "stopping a \(self)")
        switch self {
            case .compose(let intent): intent.stop(terminal)
            case .dispatch(let intent): intent.stop(terminal)
            case .observe(let intent): intent.stop(terminal)
            case .evaluate(let intent): intent.stop(terminal)
            case .search(let intent): intent.stop(terminal)
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
        Trace.say(String(describing: Self.self), "composing from \(Trace.ref(origin)), recording into \(Trace.ref(transcript))")
        let receive = receiver(terminal)
        do { try start(receive) }
        catch {
            Trace.say(String(describing: Self.self), "it never started: \(error)", indent: 1)
            receive(.stopped(.string(String(describing: error))))
        }
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else {
            Trace.say(me, "that command is not in the library", indent: 1)
            throw RuntimeError.context(.missing(command))
        }
        guard let result = dispatched
        else {
            Trace.say(me, "the command resolved to no executable artifact", indent: 1)
            throw RuntimeError.context(.functionNotFound(command.descriptor.name))
        }
        if let error = result.error, !error.isEmpty {
            Trace.say(me, "the service refused to start it: \(error)", indent: 1)
            throw RuntimeError.context(.startFailed(error))
        }
        Trace.say(me, "running as pid \(result.pid) — output will arrive on its own", indent: 1)
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        let me = String(describing: Self.self)
        return { signal in
            Task { @MainActor in
                Trace.say(me, "a signal arrived — writing it into \(Trace.ref(branch)); nobody is notified, the record simply changed", indent: 1)
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal {
                    Trace.say(me, "that signal was terminal — telling the context the run is over", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }
    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
        receiver(terminal)(.stopped(.reference(harness)))
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
        Trace.say(String(describing: Self.self), "dispatching from \(Trace.ref(origin)), recording into \(Trace.ref(transcript))")
        let receive = receiver(terminal)
        do { try start(receive) }
        catch {
            Trace.say(String(describing: Self.self), "it never started: \(error)", indent: 1)
            receive(.stopped(.string(String(describing: error))))
        }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
        receiver(terminal)(.stopped(.reference(harness)))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else {
            Trace.say(me, "that command is not in the library", indent: 1)
            throw RuntimeError.context(.missing(command))
        }
        guard let result = dispatched
        else {
            Trace.say(me, "the command resolved to no executable artifact", indent: 1)
            throw RuntimeError.context(.functionNotFound(command.descriptor.name))
        }
        if let error = result.error, !error.isEmpty {
            Trace.say(me, "the service refused to start it: \(error)", indent: 1)
            throw RuntimeError.context(.startFailed(error))
        }
        Trace.say(me, "running as pid \(result.pid) — output will arrive on its own", indent: 1)
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        let me = String(describing: Self.self)
        return { signal in
            Task { @MainActor in
                Trace.say(me, "a signal arrived — writing it into \(Trace.ref(branch)); nobody is notified, the record simply changed", indent: 1)
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal {
                    Trace.say(me, "that signal was terminal — telling the context the run is over", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }
}

struct Evaluating: Contextual {
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

    func evaluate(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        Trace.say(String(describing: Self.self), "evaluating from \(Trace.ref(origin)), recording into \(Trace.ref(transcript))")
        let receive = receiver(terminal)
        do { try start(receive) }
        catch {
            Trace.say(String(describing: Self.self), "it never started: \(error)", indent: 1)
            receive(.stopped(.string(String(describing: error))))
        }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
        receiver(terminal)(.stopped(.reference(harness)))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else {
            Trace.say(me, "that command is not in the library", indent: 1)
            throw RuntimeError.context(.missing(command))
        }
        guard let result = dispatched
        else {
            Trace.say(me, "the command resolved to no executable artifact", indent: 1)
            throw RuntimeError.context(.functionNotFound(command.descriptor.name))
        }
        if let error = result.error, !error.isEmpty {
            Trace.say(me, "the service refused to start it: \(error)", indent: 1)
            throw RuntimeError.context(.startFailed(error))
        }
        Trace.say(me, "running as pid \(result.pid) — output will arrive on its own", indent: 1)
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        let me = String(describing: Self.self)
        return { signal in
            Task { @MainActor in
                Trace.say(me, "a signal arrived — writing it into \(Trace.ref(branch)); nobody is notified, the record simply changed", indent: 1)
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal {
                    Trace.say(me, "that signal was terminal — telling the context the run is over", indent: 1)
                    terminal(signal, branch)
                }
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
        Trace.say(String(describing: Self.self), "observing from \(Trace.ref(origin)), recording into \(Trace.ref(transcript))")
        let receive = receiver(terminal)
        do { try start(receive) }
        catch {
            Trace.say(String(describing: Self.self), "it never started: \(error)", indent: 1)
            receive(.stopped(.string(String(describing: error))))
        }
    }

    func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? { nil }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
        receiver(terminal)(.stopped(.reference(harness)))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else {
            Trace.say(me, "that command is not in the library", indent: 1)
            throw RuntimeError.context(.missing(command))
        }
        guard let result = dispatched
        else {
            Trace.say(me, "the command resolved to no executable artifact", indent: 1)
            throw RuntimeError.context(.functionNotFound(command.descriptor.name))
        }
        if let error = result.error, !error.isEmpty {
            Trace.say(me, "the service refused to start it: \(error)", indent: 1)
            throw RuntimeError.context(.startFailed(error))
        }
        Trace.say(me, "running as pid \(result.pid) — output will arrive on its own", indent: 1)
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        let me = String(describing: Self.self)
        return { signal in
            Task { @MainActor in
                Trace.say(me, "a signal arrived — writing it into \(Trace.ref(branch)); nobody is notified, the record simply changed", indent: 1)
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal {
                    Trace.say(me, "that signal was terminal — telling the context the run is over", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }
}

struct Searching: Contextual {
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

    func search(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        Trace.say(String(describing: Self.self), "searching from \(Trace.ref(origin)), recording into \(Trace.ref(transcript))")
        let receive = receiver(terminal)
        do { try start(receive) }
        catch {
            Trace.say(String(describing: Self.self), "it never started: \(error)", indent: 1)
            receive(.stopped(.string(String(describing: error))))
        }
    }

    func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
        receiver(terminal)(.stopped(.reference(harness)))
    }

    private func start(_ signal: @escaping (Signal) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(rendered: arguments, environment: environment, output: signal) })
        else {
            Trace.say(me, "that command is not in the library", indent: 1)
            throw RuntimeError.context(.missing(command))
        }
        guard let result = dispatched
        else {
            Trace.say(me, "the command resolved to no executable artifact", indent: 1)
            throw RuntimeError.context(.functionNotFound(command.descriptor.name))
        }
        if let error = result.error, !error.isEmpty {
            Trace.say(me, "the service refused to start it: \(error)", indent: 1)
            throw RuntimeError.context(.startFailed(error))
        }
        Trace.say(me, "running as pid \(result.pid) — output will arrive on its own", indent: 1)
    }

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (Signal) -> Void {
        let branch = transcript
        let me = String(describing: Self.self)
        return { signal in
            Task { @MainActor in
                Trace.say(me, "a signal arrived — writing it into \(Trace.ref(branch)); nobody is notified, the record simply changed", indent: 1)
                Transcript.update(branch) { $0.insert(signal) }
                if signal.terminal {
                    Trace.say(me, "that signal was terminal — telling the context the run is over", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }
}
