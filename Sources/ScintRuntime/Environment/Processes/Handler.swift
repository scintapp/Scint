import Foundation


enum Intent: CaseIterable, Codable, Sendable {
    case compose, dispatch, evaluate, search

    var rawValue: String { String(describing: self) }

    var forms: (label: String, running: String, completed: String) {
        switch self {
            case .compose: ("Compose", "Composing", "Composed")
            case .dispatch: ("Dispatch", "Dispatching", "Dispatched")
            case .evaluate: ("Evaluate", "Evaluating", "Evaluated")
            case .search: ("Research", "Researching", "Researched")
        }
    }
}
struct Handler: Contextual {
    let key: Key
    let harness: Reference
    let arguments: [String: Value]
    var transcript: Reference

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String: Value]) {
        self.key = .context(origin)
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }

    var environment: [String: String] { ["SCINT_CONTEXT": key.id.uuidString.lowercased()] }

    var intent: Intent {
        guard let intent = Harness.with(harness, { $0.intent })
        else { fatalError("No intent found for origin harness \(String(describing: harness))") }
        return intent
    }

    func start(_ terminal: @Sendable @escaping (Signal, Reference) -> Void) {
        do {
            try compose(handle(terminal))
        } catch {
            let signal = Signal.failed(harness, .string(String(describing: error)))
            let branch = transcript

            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    private func compose(_ output: @escaping (String) -> Void) throws {
        guard let interface = Harness.with(harness, { $0.run(arguments, environment, output) })
        else { throw RuntimeError.context(.missing(harness)) }
        guard let result = interface
        else { throw RuntimeError.context(.functionNotFound(harness.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    private func handle(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let value = Value.string(text)
            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(harness, value)
                case .some: .failed(harness,  value)
                case nil: .updated(harness, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value, case .string("message")? = fields["type"]
                    else { return false }
                    return true
                }

                let readings = Parser.read(value)
                let root = Transcript.with(transcript, { $0.origin })

                Transcript.update(transcript) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Join(transcript, harness, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Join(transcript, harness, reading))
                        }
                    }
                }

                if signal.terminal { terminal(signal, transcript) }
            }
        }
    }

    static func exit(of line: String) -> Int? {
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
