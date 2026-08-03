import Foundation


enum ContextMapper {
    static func render(_ origin: Reference) -> [Value] {
        let rendered = Space.with(origin, { $0.rendered }) ?? Workspace.with(origin, { $0.rendered }) ?? ""
        let components = Space.with(origin, { $0.components }) ?? Workspace.with(origin, { $0.components }) ?? []
        var values = rendered.isEmpty ? [] : [Value.string(rendered)]
        values.append(contentsOf: components.sorted {
            let result = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
            return result == .orderedSame ? $0.id.uuidString < $1.id.uuidString : result == .orderedAscending
        }.map(Value.reference))
        return values
    }

    static func config(_ origin: Reference) -> Config {
        Space.with(origin, { $0.config }) ?? Workspace.with(origin, { $0.config }) ?? [:]
    }

    static func continuation(_ origin: Reference) -> Reference? {
        let sheets = Space.with(origin, { $0.sheets }) ?? Workspace.with(origin, { $0.sheets }) ?? []
        guard let input = sheets.first,
              let selected = Sheet.with(input, { sheet -> String? in
                  sheet.blocks.reversed().compactMap { block -> String? in
                      guard case .text(_, let value) = block else { return nil }
                      return Properties.load(value)?["selected.transcript"]?.string
                  }.first
              }).flatMap({ $0 }),
              let id = UUID(uuidString: selected)
                else { return nil }
        return Runtime.shared.transcripts(for: origin).first { $0.type == Transcript.self && $0.id == id }
    }
}

struct Context: Contextual {
    let key: Key
    let origin: Reference
    var transcript: Reference
    private(set) var intents: [Intent] = []

    enum Intent: Codable, Sendable {
        case compose(Composing)
        case dispatch(Dispatching)
        case observe(Observing)
        case execute(Executing)
        case traverse(Traversing)

        var transcript: Reference {
            switch self {
                case .compose(let intent): return intent.transcript
                case .dispatch(let intent): return intent.transcript
                case .observe(let intent): return intent.transcript
                case .execute(let intent): return intent.transcript
                case .traverse(let intent): return intent.transcript
            }
        }
    }

    init(_ origin: Reference) {
        self.key = .context(origin.contextId)
        self.origin = origin
        self.transcript = origin
    }

    var harness: Harness? {
        if let space = Space.with(origin, { $0 }), let ref = space.harness { return Harness.with(ref, { $0 }) }
        if let workspace = Workspace.with(origin, { $0 }) { return Harness.with(workspace.harness, { $0 }) }
        return nil
    }

    mutating func compose(_ signal: Signal) {
        guard case .eval(let source) = signal, source == origin, let harness else { return }
        update(transcript, signal: signal)

        let resumable = harness.parameters.contains {
            guard case .argument(let name, _, _, _) = $0 else { return false }
            return name == "continuation"
        }
        let continued = resumable ? ContextMapper.continuation(origin) : nil
        let branch = continued ?? Transcript.new("\(harness.intent) Transcript".capitalized, owner: origin)
        if continued == nil { update(transcript, ref: branch, key: key) }

        do {
            var parsed = try Parser.parse(ContextMapper.render(origin), config: ContextMapper.config(origin), parameters: harness.parameters)
            if let continued, let continuation = Parser.continuation(.reference(continued)) {
                parsed["continuation"] = continuation
                parsed = try Parser.parse(parsed, parameters: harness.parameters)
            }
            recordEnvironment(branch)
            let intent = parse(harness, transcript: branch, values: parsed)
            intents.append(intent)
            process(intent, harness: harness, values: parsed)
        } catch {
            receive(.failed(.string(String(describing: error))), from: branch)
        }
    }

    func parse(_ harness: Harness, transcript: Reference, values: [String: Value]) -> Intent {
        let targets = harness.parameters.compactMap { parameter -> Value? in
            guard case .target(let name, _, let value) = parameter else { return nil }
            return values[name] ?? value
        }
        let refs = targets.flatMap(\.references)

        switch harness.intent {
            case .compose:
                var intent = Composing(origin)
                intent.harness = harness.ref
                intent.transcript = transcript
                return .compose(intent)
            case .dispatch:
                var intent = Dispatching(origin)
                intent.harness = harness.ref
                intent.commands = refs.filter { $0.type == Command.self }
                intent.transcript = transcript
                return .dispatch(intent)
            case .observe:
                var intent = Observing(origin)
                intent.harness = harness.ref
                intent.action = values["action"]?.references.first ?? origin
                intent.target = values["target"]?.references.first
                intent.transcript = transcript
                return .observe(intent)
            case .execute:
                var intent = Executing(origin)
                intent.harness = harness.ref
                intent.transcript = transcript
                return .execute(intent)
            case .traverse:
                var intent = Traversing(origin)
                intent.harness = harness.ref
                intent.route.objective = refs.first
                intent.route.next = refs
                intent.transcript = transcript
                return .traverse(intent)
        }
    }

    func process(_ intent: Intent, harness: Harness, values: [String: Value], started: Reference? = nil) {
        update(intent.transcript, signal: .started(started ?? harness.ref))
        let inputs = Transcript.with(intent.transcript) { transcript in
            transcript.entries.compactMap { entry -> Reference? in
                guard case .input(let ref, _) = entry else { return nil }
                return ref
            }
        } ?? []
        let origin = self.origin
        let root = self.transcript
        let transcript = intent.transcript
        let records = Set([root, transcript] + inputs)
        let receive: @Sendable (Signal) -> Void = { signal in
            Task { @MainActor in
                Composer.shared.receive(signal, origin: origin, transcript: transcript)
                guard signal.terminal else { return }
                do { try await Library.shared.save(records) }
                catch { fatalError("Persistence failed: \(error)") }
            }
        }

        Task.detached {
            do {
                try await Library.shared.save(records)
                let terminal = switch intent {
                    case .compose(let intent): try intent.compose(values, signal: receive)
                    case .dispatch(let intent): try intent.dispatch(values, signal: receive)
                    case .observe(let intent): try intent.observe(values, signal: receive)
                    case .execute(let intent): try intent.execute(values, signal: receive)
                    case .traverse(let intent): try intent.traverse(values, signal: receive)
                }
                if let terminal { receive(terminal) }
            } catch {
                receive(.failed(.string(String(describing: error))))
            }
        }
    }

    mutating func receive(_ signal: Signal, from branch: Reference) {
        update(branch, signal: signal)
        guard signal.terminal else { return }
        update(transcript, signal: signal)
        intents.removeAll { $0.transcript == branch }
    }

    mutating func observe(_ target: Reference) {
        guard let harness, harness.intent == .observe else { return }
        do {
            let values = try Parser.parse(ContextMapper.render(origin), config: ContextMapper.config(origin), parameters: harness.parameters)
            guard case .observe(var intent) = parse(harness, transcript: origin, values: values), let observed = intent.target else { return }
            guard observed == target || Runtime.shared.context(from: observed).contains(target) else { return }
            let branch = Transcript.new("Observe Transcript", owner: origin)
            update(transcript, signal: .updated(.reference(target)))
            update(transcript, ref: branch, key: key)
            intent.transcript = branch
            intent.reaction = true
            intents.append(.observe(intent))
            process(.observe(intent), harness: harness, values: values, started: intent.action)
        } catch {
            update(transcript, signal: .failed(.string(String(describing: error))))
        }
    }

    func update(_ transcript: Reference, signal: Signal? = nil, ref: Reference? = nil, key: Key? = nil) {
        if let signal {
            Transcript.update(transcript) {
                $0.insert(signal)
                for (key, value) in Parser.properties(signal) { $0.insert(value, for: key) }
            }
        }
        else if let ref, Sheet.with(ref, { $0 }) != nil { Transcript.update(transcript) { $0.insert(ref) } }
        else if let ref, let key, Transcript.with(ref, { $0 }) != nil { Transcript.update(transcript) { $0.insert(ref, key) } }
        else { return }
    }

    private func recordEnvironment(_ transcript: Reference) {
        let recorded = Set(Transcript.with(transcript) { transcript in
            transcript.entries.compactMap { entry -> Reference? in
                guard case .input(let ref, _) = entry else { return nil }
                return ref
            }
        } ?? [])
        var includedInput = false

        for sheet in sheets {
            if sheet.descriptor.tags.contains("input") {
                guard !includedInput else { continue }
                includedInput = true
            }
            guard !recorded.contains(sheet) else { continue }
            update(transcript, ref: sheet)
        }
    }

    private var sheets: [Reference] { Space.with(origin, { $0.sheets }) ?? Workspace.with(origin, { $0.sheets }) ?? [] }

    static func compose(_ origin: Reference) -> Context {
        var context = Self(origin)
        let transcripts = Runtime.shared.transcripts(for: origin)
        let tagged = transcripts.filter { $0.descriptor.tags.contains("context") }
        let children = Set(transcripts.flatMap { ref in
            Transcript.with(ref, { transcript in
                transcript.entries.compactMap { entry -> Reference? in
                    guard case .transcript(let child, _, _) = entry else { return nil }
                    return child
                }
            }) ?? []
        })
        let roots = transcripts.filter { !children.contains($0) }
        let named = transcripts.filter { $0.descriptor.name == origin.descriptor.name }
        let candidates = !tagged.isEmpty ? tagged : (!roots.isEmpty ? roots : named)
        context.transcript = candidates.min {
            $0.descriptor.created < $1.descriptor.created
        } ?? Transcript.new(origin.descriptor.name, owner: origin)
        _ = Catalog.shared.update(context.transcript) { $0.tags.insert("context") }
        return context
    }
}
