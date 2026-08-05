import Foundation


enum Intent: Codable, Sendable {
    case compose(Composing)
    case dispatch(Dispatching)
    case observe(Observing)
    case execute(Executing)
    case traverse(Traversing)
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
        self.key = .context(origin)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func compose(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = Harness.with(harness, { $0.start(values, output: signal) }) ?? nil
        else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
        return nil
    }
}

struct Dispatching: Contextual {
    let key: Key
    let origin: Reference
    var harness: Reference
    var transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = origin
        self.harness = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func dispatch(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = Harness.with(harness, { $0.start(values, output: signal) }) ?? nil
        else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
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
        self.key = .context(origin)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func execute(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? {
        guard let result = Harness.with(harness, { $0.start(values, output: signal) }) ?? nil
        else { throw RuntimeError.context(.startFailed("Harness start returned no result.")) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
        return nil
    }
}

struct Observing: Contextual {
    let key: Key
    let origin: Reference
    var harness: Reference
    var transcript: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func observe(_ values: [String: Value], signal: @escaping (Signal) -> Void) throws -> Signal? { .none }
    func react(_ signal: @escaping (Signal) -> Void) throws -> Signal? { .none }
}

struct Traversing: Contextual {
    let key: Key
    let origin: Reference
    var transcript: Reference
    var harness: Reference

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = origin
        self.transcript = origin
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.harness = harness
        self.transcript = transcript
    }

    func traverse(_: [String: Value], signal _: @escaping (Signal) -> Void) throws -> Signal? { .none }
}

struct Context: Contextual {
    let key: Key
    let origin: Reference
    let transcript: Reference
    var intents: [Intent] = []

    enum Intent: Codable, Sendable {
        case compose(Composing)
        case dispatch(Dispatching)
        case observe(Observing)
        case execute(Executing)
        case traverse(Traversing)
    }

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = origin
    }

    func parse() { }

    func evaluate() { }

    func update() { }

    static func new(_ origin: Reference) -> Context {
        let context = Self(origin)
        return context
    }
}
