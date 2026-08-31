import Foundation


struct Dispatching: Contextual {
    let key: Key
    let harness: Reference
    let transcript: Reference
    let arguments: [String]

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.harness = origin
        self.transcript = origin
        self.arguments = []
    }

    init(_ origin: Reference, harness: Reference, transcript: Reference, arguments: [String]) {
        self.key = .context(origin)
        self.harness = harness
        self.transcript = transcript
        self.arguments = arguments
    }
    
    func dispatch(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        do { try start(handle(terminal)) }
        catch {
            let signal = Signal.failed(harness, .dispatching, .string(String(describing: error)))
            let branch = transcript

            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let environment = ["SCINT_CONTEXT": key.id.uuidString.lowercased()]

        guard let command = Harness.with(harness, { $0.command })
                else { throw RuntimeError.context(.missing(harness)) }

        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
                else { throw RuntimeError.context(.missing(command)) }

        guard let result = dispatched
                else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }

        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    func handle(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) -> @Sendable (String) -> Void {
        return { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let value = Value.string(text)

            let signal: Signal = switch Self.exit(of: text) {
                case .some(0): .completed(harness, .evaluating, value)
                case .some: .failed(harness, .evaluating, value)
                case nil: .updated(harness, .evaluating, value)
            }

            Task { @MainActor in
                func message(_ value: Value) -> Bool {
                    guard case .collection(let fields) = value, case .string("message")? = fields["type"]
                            else { return false }
                    return true
                }

                let readings = Reading.read(value)
                let root = Transcript.with(transcript, { $0.origin })

                Transcript.update(transcript) { record in
                    if signal.terminal { record.insert(signal) }
                    for reading in readings where !message(reading) {
                        record.insert(Chunk(transcript, harness, reading))
                    }
                }

                if let root, root.type == Transcript.self {
                    Transcript.update(root) { record in
                        for reading in readings where message(reading) {
                            record.insert(Chunk(transcript, harness, reading))
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

    func stop() {
        guard Runtime.shared.services.stop(context: key.id)
                else { return }
    }
}
