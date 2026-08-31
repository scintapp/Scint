import Foundation


struct Searching: Contextual {
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

    func search(_ terminal: @escaping @Sendable (Signal, Reference) -> Void) {
        let receive = Receiver(harness: harness, transcript: transcript)
        do { try start(receive.handle(terminal)) }
        catch {
            let signal = Signal.failed(harness, .evaluating, .string(String(describing: error)))
            let branch = transcript
            Task { @MainActor in
                Transcript.update(branch) { $0.insert(signal) }
                terminal(signal, branch)
            }
        }
    }

    private func start(_ output: @escaping (String) -> Void) throws {
        let me = String(describing: Self.self)
        guard let command = Harness.with(harness, { $0.command })
        else { throw RuntimeError.context(.missing(harness)) }
        let environment = ["SCINT_CONTEXT": key.id.uuidString.lowercased()]
        guard let dispatched = Command.with(command, { $0.dispatch(arguments, environment: environment, output: output) })
        else { throw RuntimeError.context(.missing(command)) }
        guard let result = dispatched
        else { throw RuntimeError.context(.functionNotFound(command.descriptor.name)) }
        if let error = result.error, !error.isEmpty { throw RuntimeError.context(.startFailed(error)) }
    }

    func stop() {
        let me = String(describing: Self.self)
        guard Runtime.shared.services.stop(context: key.id)
                else { return }
    }
}
