import Foundation


struct Context: Contextual {
    let key: Key
    let origin: Reference
    var transcript: Reference
    private(set) var handlers: [Handler] = []

    init(_ origin: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = origin
    }

    var harness: Reference {
        guard let harness = Space.with(origin, { $0.harness }), Harness.with(harness!, { $0 }) != nil
        else { fatalError("No harness found for origin \(String(describing: origin.type))") }
        return harness!
    }

    var intent: Intent {
        guard let intent = Harness.with(harness, { $0.intent })
        else { fatalError("No intent found for origin harness \(String(describing: harness))") }
        return intent
    }

    var transcripts: [Reference] {
        guard let root = Transcript.with(self.transcript, { $0 }) else { return [] }
        return root.branches
    }

    mutating func handle(_ signal: Signal) {
        switch signal {
            case .composed:
                guard let composed = compose() else { return }
                process(composed)

            case .started, .updated:
                Transcript.update(transcript) { $0.insert(signal) }

            case .stopped, .completed, .failed:
                Transcript.update(transcript) { $0.insert(signal) }
                handlers.removeAll()
        }
    }

    private mutating func compose() -> (intent: Intent, branch: Reference, arguments: [String: Value])? {
        guard let harness = Harness.with(self.harness, { $0 }) else { return nil }
        let closure = Space.with(origin, { $0.closure })!
        let intent = harness.intent
        let branch = self.branch(for: intent)
        let material = Closure.with(closure, { $0.input })!
        let input = Material.update(material) { material -> String in material.dump() } ?? ""
        let arguments = compose(input)

        update(branch)
        update(input, from: material)
        handle(.started(.reference(origin)))

        return (intent, branch, arguments)
    }

    private mutating func compose(_ input: String) -> [String: Value] {
        let config = Space.with(origin, { $0.config }) ?? [:]
        let inputValue = Value.string(Renderer.evaluation(origin, transcript: transcript, input: input))
        let values = Dictionary(uniqueKeysWithValues: config.map { ($0.key, $0.value) })
        var arguments: [String: Value] = [:]

        do {
            try Harness.with(harness) { harness in
                arguments = try harness.parse(values, input: inputValue)
                return arguments
            }
        } catch {
            handle(.failed(.collection(["ref": .reference(harness), "text": .string(String(describing: error))])))
        }
        return arguments
    }

    private mutating func process(_ composed: (intent: Intent, branch: Reference, arguments: [String: Value])) {
        let harness = self.harness
        let branch = composed.branch
        let arguments = composed.arguments
        let handler = Handler(origin, harness: harness, transcript: branch, arguments: arguments)
        handlers.append(handler)
        let transcript = self.transcript
        handler.start { signal, _ in
            Transcript.update(transcript) { $0.insert(signal) }
        }
    }

    private func update(_ request: String, from source: Reference) {
        Transcript.update(transcript) { $0.insert(Join(transcript, source, .string(request))) }
    }

    private func update(_ branch: Reference) {
        Transcript.update(transcript) { root in
            if !root.branches.contains(branch) { root.insert(branch, intent: intent ) }
        }
    }

    private func branch(for intent: Intent) -> Reference {
        let name = "\(String(describing: intent)) Context"
        if let found = (Transcript.with(transcript, { $0.branches }) ?? []).first(where: { $0.descriptor.name == name }) {
            return found
        }
        let branch = Transcript.new(transcript, intent: intent)
        Transcript.update(transcript) { $0.insert(branch, intent: intent) }
        return branch
    }

    static func new(_ origin: Reference) -> Context {
        let roots = Space.with(origin, { $0.transcripts }) ?? []
        let existing = roots.first { reference in
            Transcript.with(reference) { transcript in
                transcript.entries.contains { entry in
                    guard case .event(.composed(.reference(let source)), _) = entry else { return false }
                    return source == origin
                }
            } == true
        }

        var context = Self(origin)
        if let existing { context.transcript = existing }
        else {
            let transcript = Transcript.new(origin)
            Transcript.update(transcript) { $0.insert(.composed(.reference(origin))) }
            context.transcript = transcript
        }
        return context
    }
}
