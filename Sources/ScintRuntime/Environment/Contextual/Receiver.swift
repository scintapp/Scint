import Foundation


struct Receiver: Sendable {
    let harness: Reference
    let transcript: Reference

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
}
