import Foundation


/// Temporary narration for the Contextual module. Scaffolding, not architecture —
/// delete this file and every `Trace.` call site once the flow is understood.
///
/// Filter the console with `[` to read the story, or with a single scope like
/// `[Serialization]` to follow one stage.

enum Trace {
    static func say(_ scope: String, _ message: String, indent: Int = 0) {
        print("[\(scope)] \(String(repeating: "  ", count: indent))\(message)")
    }
    static func name(_ ref: Reference) -> String { Catalog.shared.get(ref)?.name ?? "unnamed" }
    static func id(_ ref: Reference) -> String { String(ref.id.uuidString.prefix(8)).lowercased() }
    static func ref(_ value: Reference) -> String { "\"\(name(value))\" \(id(value))" }
    static func kind(_ value: Reference) -> String { value.type.map { "\($0)" } ?? "unresolved" }
}

struct Context: Contextual {
    let key: Key
    let origin: Reference
    let transcript: Reference
    private(set) var intents: [Intent] = []

    init(_ origin: Reference) { self = Self.new(origin) }

    private init(_ origin: Reference, transcript: Reference) {
        self.key = .context(origin)
        self.origin = origin
        self.transcript = transcript
    }

    var harness: Reference? {
        guard let ref = Space.with(origin, { $0.harness }) ?? Workspace.with(origin, { $0.harness })
        else { return nil }
        return ref
    }

    mutating func start(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        Trace.say("Context", "fire — \(Trace.ref(origin)) was asked to run")
        guard let harness else {
            Trace.say("Context", "it has no active harness, so there is nothing to become", indent: 1)
            return
        }
        Trace.say("Context", "its active harness is \(Trace.ref(harness))", indent: 1)

        let branch = intentTranscript()

        Transcript.update(transcript) { root in
            root.insert(.started(.reference(origin)))
            if !root.entries.contains(where: { if case .transcript(_, let ref, _) = $0 { ref == branch } else { false } }) {
                Trace.say("Context", "linking the branch into root \(Trace.ref(transcript)) for the first time", indent: 1)
                root.insert(.context(branch), branch)
            }
        }

        do {
            let config = Space.with(origin, { $0.config }) ?? Workspace.with(origin, { $0.config }) ?? [:]
            if case .string(let input)? = config["prompt"], !input.isEmpty {
                Trace.say("Context", "the space carries a prompt of \(input.count) characters — recording it as input", indent: 1)
                Transcript.update(branch) { $0.insert("input", .string(input)) }
            } else {
                Trace.say("Context", "the space carries no prompt", indent: 1)
            }

            Trace.say("Context", "rendering the space through its own recursive projection", indent: 1)
            let serialized = Runtime.shared.rendered(origin)
            Trace.say("Context", "keeping that document in the record", indent: 1)
            Transcript.update(branch) { $0.insert("context", .string(serialized)) }

            var values = Dictionary(uniqueKeysWithValues: config.map { ($0.key, $0.value) })
            values["prompt"] = .string(serialized)

            guard let command = Harness.with(harness, { $0.command }),
                  let arguments = Command.with(command, { command in
                      Harness.with(harness, { command.rendered(with: values) + $0.rendered(with: values) })
                  }) ?? nil
            else { throw RuntimeError.context(.missing(harness)) }
            Trace.say("Context", "rendered \(arguments.count) argument(s) straight from config — nothing validates them now", indent: 1)
            guard let intent = intent(branch, arguments: arguments) else {
                Trace.say("Context", "no intent could be built for that harness", indent: 1)
                return
            }
            intents.append(intent)
            Trace.say("Context", "\(intents.count) intent(s) now live on this context", indent: 1)
            intent.start(terminal)
        } catch {
            Trace.say("Context", "the fire failed before dispatch: \(error)", indent: 1)
            let signal = Signal.stopped(.string(String(describing: error)))
            Transcript.update(branch) { $0.insert(signal) }
            terminal(signal, branch)
        }
    }

    mutating func stop(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        Trace.say("Context", "stopping \(intents.count) live intent(s) on \(Trace.ref(origin))")
        for intent in intents { intent.stop(terminal) }
    }

    mutating func complete(_ signal: Signal, from branch: Reference) {
        guard signal.terminal else { return }
        Trace.say("Context", "a run finished in \(Trace.ref(branch)) — echoing the outcome into the root")
        Transcript.update(transcript) { $0.insert(signal) }
        intents.removeAll { $0.transcript == branch }
        Trace.say("Context", "\(intents.count) intent(s) remain — the space is \(intents.isEmpty ? "idle again" : "still working")", indent: 1)
    }

    static func new(_ origin: Reference) -> Context {
        let roots = Space.with(origin, { $0.transcripts }) ?? Workspace.with(origin, { $0.transcripts }) ?? []
        if let transcript = roots.first(where: { reference in
            Transcript.with(reference) { transcript in
                transcript.entries.contains { entry in
                    guard case .event(_, .started(.reference(let source)), _) = entry else { return false }
                    return source == origin
                }
            } == true
        }) {
            Trace.say("Context", "reusing the existing root transcript \(Trace.ref(transcript)) for \(Trace.ref(origin))")
            return Self(origin, transcript: transcript)
        }

        Trace.say("Context", "no root transcript yet for \(Trace.ref(origin)) — making one")
        let transcript = Transcript.new(origin.descriptor.name, owner: origin)
        Transcript.update(transcript) { $0.insert(.started(.reference(origin))) }
        return Self(origin, transcript: transcript)
    }

    private func intent(_ transcript: Reference, arguments: [String]) -> Intent? {
        guard let harness, let kind = Harness.with(harness, { $0.intent }) else { return nil }
        Trace.say("Context", "the harness declares intent \(kind) — building that shape", indent: 1)
        switch kind {
            case .compose: return .compose(Composing(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .dispatch: return .dispatch(Dispatching(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .observe: return .observe(Observing(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .evaluate: return .evaluate(Evaluating(origin, harness: harness, transcript: transcript, arguments: arguments))
            case .search: return .search(Searching(origin, harness: harness, transcript: transcript, arguments: arguments))
        }
    }

    private func intentTranscript() -> Reference {
        if let value = Space.with(origin, { $0.config["transcript"] })
                ?? Workspace.with(origin, { $0.config["transcript"] }),
           case .reference(let focused) = value,
           focused != transcript,
           !intents.contains(where: { $0.transcript == focused }),
           (Space.with(origin, { $0.transcripts }) ?? Workspace.with(origin, { $0.transcripts }) ?? []).contains(focused) {
            Trace.say("Context", "the space points at a specific transcript — writing there instead", indent: 1)
            return focused
        }
        let name = harness.flatMap { Harness.with($0, { "\($0.intent)".capitalized }) } ?? "Intent"
        let branches = Transcript.with(transcript, { $0.entries })?.compactMap { entry -> Reference? in
            guard case .transcript(_, let ref, _) = entry else { return nil }
            return ref
        } ?? []
        if let existing = branches.first(where: { $0.descriptor.name == name }) {
            Trace.say("Context", "reusing the \(name) branch — every run of this intent shares it", indent: 1)
            return existing
        }

        Trace.say("Context", "opening a new \(name) branch under the root", indent: 1)
        return Transcript.new(name, owner: transcript)
    }
}
