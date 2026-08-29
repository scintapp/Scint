import Foundation


// MARK: - Intent
// With the exception of `Evaluating`, intents are mostly stubs and scaffold. Each intent diverges here; the
// identical implementations are merely sketches, not accidental duplication.


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
            let signal = Signal.failed(harness, .composing, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }

        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]

        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })

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

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        let branch = transcript
        let source = harness
        let me = String(describing: Self.self)

        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(source, .composing, value)
                case .some: .failed(source, .composing, value)
                case nil: .updated(source, .composing, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value,
                          case .string("message")? = fields["type"] else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(branch, { $0.origin })
                Trace.say(me, "a line arrived — \(readings.count) chunk(s) read into \(Trace.ref(branch))", indent: 1)

                Transcript.update(branch) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(branch, source, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(branch, source, reading))
                        }
                    }
                }
                if signal.terminal {
                    Trace.say(me, "that line ended the run — telling the context", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }

    private static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
    }
    func stop() {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
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
            let signal = Signal.failed(harness, .dispatching, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    func stop() {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
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

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        let branch = transcript
        let source = harness
        let me = String(describing: Self.self)

        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(source, .dispatching, value)
                case .some: .failed(source, .dispatching, value)
                case nil: .updated(source, .dispatching, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value,
                          case .string("message")? = fields["type"] else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(branch, { $0.origin })
                Trace.say(me, "a line arrived — \(readings.count) chunk(s) read into \(Trace.ref(branch))", indent: 1)

                Transcript.update(branch) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(branch, source, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(branch, source, reading))
                        }
                    }
                }
                if signal.terminal {
                    Trace.say(me, "that line ended the run — telling the context", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }

    private static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
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
            let signal = Signal.failed(harness, .evaluating, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    func stop() {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
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

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        let branch = transcript
        let source = harness
        let me = String(describing: Self.self)

        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(source, .evaluating, value)
                case .some: .failed(source, .evaluating, value)
                case nil: .updated(source, .evaluating, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value,
                          case .string("message")? = fields["type"] else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(branch, { $0.origin })
                Trace.say(me, "a line arrived — \(readings.count) chunk(s) read into \(Trace.ref(branch))", indent: 1)

                Transcript.update(branch) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(branch, source, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(branch, source, reading))
                        }
                    }
                }
                if signal.terminal {
                    Trace.say(me, "that line ended the run — telling the context", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }

    private static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
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
            let signal = Signal.failed(harness, .observing, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? { nil }

    func stop() {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
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

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        let branch = transcript
        let source = harness
        let me = String(describing: Self.self)

        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(source, .observing, value)
                case .some: .failed(source, .observing, value)
                case nil: .updated(source, .observing, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value,
                          case .string("message")? = fields["type"] else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(branch, { $0.origin })
                Trace.say(me, "a line arrived — \(readings.count) chunk(s) read into \(Trace.ref(branch))", indent: 1)

                Transcript.update(branch) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(branch, source, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(branch, source, reading))
                        }
                    }
                }
                if signal.terminal {
                    Trace.say(me, "that line ended the run — telling the context", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }

    private static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
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
            let signal = Signal.failed(harness, .searching, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    func stop() {
        let me = String(describing: Self.self)
        Trace.say(me, "asking the service to kill everything under this context")
        guard Runtime.shared.services.stop(context: origin.contextId) else {
            Trace.say(me, "nothing was running under it", indent: 1)
            return
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command }) else {
            Trace.say(me, "the harness names no command — nothing to run", indent: 1)
            throw RuntimeError.context(.missing(harness))
        }
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        Trace.say(me, "handing \(arguments.count) argument(s) to \(Trace.ref(command))", indent: 1)
        Trace.say(me, "the process will carry SCINT_CONTEXT \(environment["SCINT_CONTEXT"] ?? "") — this is how it reaches back", indent: 1)
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
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

    private func receiver(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        let branch = transcript
        let source = harness
        let me = String(describing: Self.self)

        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(source, .searching, value)
                case .some: .failed(source, .searching, value)
                case nil: .updated(source, .searching, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value,
                          case .string("message")? = fields["type"] else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(branch, { $0.origin })
                Trace.say(me, "a line arrived — \(readings.count) chunk(s) read into \(Trace.ref(branch))", indent: 1)

                Transcript.update(branch) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(branch, source, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(branch, source, reading))
                        }
                    }
                }
                if signal.terminal {
                    Trace.say(me, "that line ended the run — telling the context", indent: 1)
                    terminal(signal, branch)
                }
            }
        }
    }

    private static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
    }
}
