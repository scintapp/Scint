@testable import AgencyRuntime
import Foundation
import Testing


@MainActor
@Suite("Harness composition", .serialized)
struct HarnessCompositionTests {
    @Test("harness intent and parameter shape are stored at registration")
    func harnessShapeIsStoredAtRegistration() {
        let exec = Artifact.register("shape.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("shape.command", exec: exec)
        let parameter = Harness.Parameter.target(name: "agency.exec.context", type: .reference(Space.self), default: nil)
        let harness = Harness.register("shape.harness", command: command, intent: .execute, parameters: [parameter])

        #expect(Harness.with(harness, { $0.intent }) == .execute)
        #expect(Harness.with(harness, { $0.parameters }) == [parameter])
    }

    @Test("harness renders authored and supplied values in declaration order")
    func harnessRendersAuthoredAndSuppliedValues() throws {
        let exec = Artifact.register("render.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("render.command", exec: exec)
        let harness = Harness.register(
            "render.harness",
            command: command,
            intent: .execute,
            parameters: [
                .argument(name: "prompt", type: .string(""), required: true),
                .argument(name: "model", type: .collection(["--model": .string("")])),
                .command(content: "--sandbox", value: .string("workspace-write"))
            ]
        )
        let instance = Harness.with(harness, { $0 })!
        let values = try Parser.parse(["prompt": .string("Hello"), "model": .string("gpt")], parameters: instance.parameters)

        #expect(instance.rendered(with: values) == ["Hello", "--model", "gpt", "--sandbox", "workspace-write"])
    }

    @Test("trigger creates an active observing intent")
    func triggerCreatesObservingIntent() {
        let exec = Artifact.register("observe.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("observe.command", exec: exec)
        let harness = Harness.register(
            "observe.harness",
            command: command,
            intent: .observe,
            parameters: [.argument(name: "watch", type: .string(""))]
        )
        let space = Space.new("Observed Space")
        Space.update(space) { $0.harness = harness }

        let composition = Runtime.shared.trigger(space)
        let observing = composition?.intents.compactMap { intent -> Observing? in
            guard case .observe(let observing) = intent else { return nil }
            return observing
        }.first

        #expect(composition?.state == .running)
        #expect(observing?.origin == space)
        #expect(observing?.harness == harness)
    }

    @Test("terminal signals close intent branches without flattening transcripts")
    func terminalSignalsCloseIntentBranches() {
        let target = Artifact.register("traverse.target", URL(string: "https://example.com/target")!)
        let exec = Artifact.register("traverse.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("traverse.command", exec: exec)
        let harness = Harness.register(
            "traverse.harness",
            command: command,
            intent: .traverse,
            parameters: [.target(name: "agency.traverse.roots", type: .reference(Artifact.self), default: .reference(target))]
        )
        let space = Space.new("Traverse Space")
        Space.update(space) { $0.harness = harness }

        let composition = Runtime.shared.trigger(space)!
        let root = composition.transcript
        let entries = Transcript.with(root, { $0.entries })!
        let branch = entries.compactMap(\.transcript).first!

        #expect(composition.state == .completed)
        #expect(composition.intentTranscript == branch)
        #expect(composition.intents.isEmpty)
        #expect(entries.compactMap(\.signal) == [.trigger(origin: space), .completed])
        #expect(Transcript.with(branch, { $0.entries.compactMap(\.signal) })! == [.started(harness), .completed])
    }

    @Test("space inputs belong to the intent transcript")
    func spaceInputsBelongToIntentTranscript() {
        let exec = Artifact.register("input.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("input.command", exec: exec)
        let harness = Harness.register("input.harness", command: command, intent: .observe)
        let space = Space.new("Input Transcript Space")
        let sheet = Sheet.new(space, name: "Process Input")
        Space.update(space) { $0.harness = harness }

        let composition = Runtime.shared.trigger(space)!
        let root = composition.transcript
        let branch = composition.intentTranscript!

        #expect(Transcript.with(root, { $0.entries.compactMap(\.input) })! == [])
        #expect(Transcript.with(branch, { $0.entries.compactMap(\.input).contains(sheet) }) == true)
    }

    @Test("context consumes and resets the closure input")
    func contextConsumesClosureInput() {
        let exec = Artifact.register("consume.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("consume.command", exec: exec)
        let harness = Harness.register(
            "consume.harness",
            command: command,
            intent: .execute,
            parameters: [.argument(name: "prompt", type: .string(""), required: true)]
        )
        let space = Space.new("Consume Input Space")
        let closure = Space.with(space, { $0.closure })!
        let input = Closure.with(closure, { $0.input })!
        Sheet.update(input) { $0.insert(.text(.init(), "Current message"), at: nil) }
        Space.update(space) { $0.harness = harness }

        let composition = Runtime.shared.trigger(space)!
        let current = Closure.with(closure, { $0.input })!
        let branch = composition.intentTranscript!

        #expect(current != input)
        #expect(Sheet.with(current, { $0.blocks.isEmpty }) == true)
        #expect(Sheet.with(input, { $0.rendered }) == "Current message")
        #expect(Transcript.with(branch, { $0.entries.compactMap(\.input).contains(input) }) == true)
    }

    @Test("process parsing preserves provider output without vendor classifications")
    func processParsingPreservesProviderOutput() {
        let raw = #"{"type":"error","message":"invalid model"}"#
        let provider = Parser.signals(raw)
        let terminal = Parser.signals(#"{"type":"terminated","exitCode":0}"#)

        #expect(provider == [.updated(.string(raw))])
        #expect(terminal == [.completed])
    }

    @Test("sample Codex harness builds process arguments from Values")
    func sampleCodexHarnessBuildsArguments() throws {
        let interfaces = SampleInterfaces.load()
        let harness = Harness.with(interfaces.codexHarness, { $0 })!
        let directory = Artifact.register("Codex Workspace", URL(fileURLWithPath: "/tmp/codex-workspace"))
        let sharedOne = Artifact.register("Shared One", URL(fileURLWithPath: "/tmp/shared-one"))
        let sharedTwo = Artifact.register("Shared Two", URL(fileURLWithPath: "/tmp/shared-two"))
        let values = try Parser.parse([
            "prompt": .string("Hello"),
            "model": .string("gpt-5.6"),
            "directory": .reference(directory),
            "additionalDirectories": .sequence([.reference(sharedOne), .reference(sharedTwo)]),
            "reasoningEffort": .string("high")
        ], parameters: harness.parameters)

        #expect(harness.arguments(with: values) == [
            "exec", "--json", "--color", "never", "--skip-git-repo-check",
            "--model", "gpt-5.6",
            "-C", "/tmp/codex-workspace",
            "--add-dir", "/tmp/shared-one", "/tmp/shared-two",
            "-c", "model_reasoning_effort=high",
            "--sandbox", "workspace-write",
            "Hello"
        ])
    }

    @Test("sample Observer harness renders cron triggers and preserves action references")
    func sampleObserverHarnessBuildsArguments() throws {
        let interfaces = SampleInterfaces.load()
        let harness = Harness.with(interfaces.observerHarness, { $0 })!
        let action = Space.new("Observer Action")
        let target = Sheet.new(action, name: "Observer Target")
        let values = try Parser.parse([
            "schedule": .string("0 9 * * 1-5"),
            "action": .reference(action),
            "target": .reference(target)
        ], parameters: harness.parameters)
        let commandValues = try Parser.parse([
            "schedule": .string("30 8 * * *"),
            "action": .reference(interfaces.fetchPage)
        ], parameters: harness.parameters)

        #expect(harness.intent == .observe)
        #expect(Array(harness.arguments(with: values).suffix(7)) == [
            "agency-observer", "--operation", "install", "--schedule", "0 9 * * 1-5",
            "--repeat", "false"
        ])
        #expect(values["action"] == .reference(action))
        #expect(values["target"] == .reference(target))
        #expect(commandValues["action"] == .reference(interfaces.fetchPage))
        #expect(!harness.arguments(with: values).contains(action.descriptor.name))
    }

    @Test("Observer reactions compose reachable process actions with contextual targets")
    func observerReactionsComposeReachableProcesses() throws {
        let exec = Artifact.register("observer.reaction.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("observer.reaction.command", exec: exec)
        let harness = Harness.register("observer.reaction.harness", command: command, intent: .traverse)
        let observer = Space.new("Observer Origin")
        let action = Space.new("Observer Process", owner: observer)
        let target = Sheet.new(action, name: "Observed Value")
        Space.update(action) { $0.harness = harness }

        var intent = Observing(observer)
        intent.action = action
        intent.target = target
        intent.reaction = true

        #expect(Runtime.shared.context(from: observer).contains(target))
        #expect(try intent.observe([:], signal: { _ in }) == .completed)
        #expect(Runtime.shared.context(for: action) != nil)
    }

    @Test("selected Codex transcript renders its continuation command")
    func selectedCodexTranscriptRendersContinuation() throws {
        let interfaces = SampleInterfaces.load()
        let harness = Harness.with(interfaces.codexHarness, { $0 })!
        let space = Space.new("Continuation Space")
        let transcript = Transcript.new("Continuation Transcript", owner: space)
        let id = "019f787e-22be-73d3-8d74-9f7f2c9d694c"
        let started = #"{"type":"thread.started","thread_id":"\#(id)"}"#
        Transcript.update(transcript) { $0.insert(.updated(.string(started))) }

        let selected = Value.collection(["content": .reference(transcript)])
        let continuation = Parser.continuation(selected)!
        let values = try Parser.parse(["continuation": continuation, "prompt": .string("Continue")], parameters: harness.parameters)

        #expect(harness.arguments(with: values) == [
            "exec", "--json", "--color", "never", "--skip-git-repo-check",
            "--sandbox", "workspace-write", "resume", id, "Continue"
        ])
    }

    @Test("harness definitions validate call-time values without retaining invocation state")
    func harnessDefinitionsValidateCallTimeValues() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let primaryURL = root.appendingPathComponent("A Workspace")
        let additionalURL = root.appendingPathComponent("B Shared")
        try FileManager.default.createDirectory(at: primaryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: additionalURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let primary = Artifact.register("A Workspace", primaryURL)
        let additional = Artifact.register("B Shared", additionalURL)
        let space = Space.new("Environment Space")
        Space.with(space, { $0 })?.add(primary)
        Space.with(space, { $0 })?.add(additional)

        let notes = Sheet.new(space, name: "Context Notes")
        Sheet.update(notes) { $0.insert(.text(.init(), "Persistent context"), at: nil) }
        let input = Sheet.new(space, input: true)
        Sheet.update(input) { $0.insert(.text(.init(), "Current message"), at: nil) }

        let exec = Artifact.register("environment.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("environment.command", exec: exec)
        let harnessRef = Harness.register(
            "environment.harness",
            command: command,
            intent: .execute,
            parameters: [
                .argument(name: "prompt", type: .string(""), required: true),
                .argument(name: "directory", type: .collection(["-C": .reference(Artifact.self)])),
                .argument(name: "additionalDirectories", type: .collection(["--add-dir": .sequence(.reference(Artifact.self))]))
            ]
        )
        let harness = Harness.with(harnessRef, { $0 })!
        let closure = Space.with(space, { $0.closure }).flatMap { Closure.with($0, { $0 }) }!
        let values = try Parser.parse([
            "prompt": .string(closure.rendered),
            "directory": .reference(primary),
            "additionalDirectories": .sequence([.reference(additional)])
        ], parameters: harness.parameters)

        guard case .string(let prompt) = values["prompt"] else {
            Issue.record("Expected the closure sheets to produce a prompt.")
            return
        }
        #expect(prompt.contains("# Context Notes\nPersistent context"))
        #expect(prompt.hasSuffix("# Input\nCurrent message"))
        #expect(values["directory"] == .collection(["-C": .reference(primary)]))
        #expect(values["additionalDirectories"] == .collection(["--add-dir": .sequence([.reference(additional)])]))
        #expect(harness.rendered(with: [:]).isEmpty)
    }

    @Test("root contexts reuse persisted transcripts")
    func rootContextsReusePersistedTranscripts() {
        let space = Space.new("Persistent Context \(UUID())")
        let transcript = Transcript.new("Existing Root", owner: space)
        let branch = Transcript.new("Existing Branch", owner: space)
        Transcript.update(transcript) { $0.insert(branch, .context(space.contextId)) }
        let before = Runtime.shared.transcripts(for: space)
        let context = Context.compose(space)

        #expect(context.transcript == transcript)
        #expect(Runtime.shared.transcripts(for: space) == before)
        #expect(context.transcript.descriptor.tags.contains("context"))
    }

    @Test("harness parsing enforces required values")
    func harnessParsingEnforcesRequiredValues() {
        let interfaces = SampleInterfaces.load()
        let harness = Harness.with(interfaces.codexHarness, { $0 })!
        var missing: ParsingError?

        do { _ = try Parser.parse([:], parameters: harness.parameters) }
        catch let error as ParsingError { missing = error }
        catch {}

        #expect(missing == .missingArgument("prompt"))
    }
}

private extension Transcript.Entry {
    var signal: Signal? {
        guard case .signal(let signal, _, _) = self else { return nil }
        return signal
    }

    var transcript: Reference? {
        guard case .transcript(let ref, _, _) = self else { return nil }
        return ref
    }

    var input: Reference? {
        guard case .input(let ref, _) = self else { return nil }
        return ref
    }
}
