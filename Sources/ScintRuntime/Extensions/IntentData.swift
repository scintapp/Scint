import Foundation


enum IntentInterfaces {
    struct References {
        let orchestrate: Reference
        let execute: Reference
        let retrieve: Reference
        let composer: Reference
        let dispatcher: Reference
        let searcher: Reference
    }

    private static let endpoint = "http://127.0.0.1:7345/mcp"

    @discardableResult
    static func load() -> References {
        func existing<T: Resolvable>(_ name: String, as type: T.Type) -> Reference? {
            Runtime.shared.all(as: type).first { $0.0.descriptor.name == name }?.0
        }

        func artifact(_ name: String, _ url: URL) -> Reference {
            existing(name, as: Artifact.self) ?? Artifact.register(name, url)
        }

        func command(_ name: String, _ artifact: Reference, _ parameters: [Command.Parameter], description: String? = nil) -> Reference {
            let reference = existing(name, as: Command.self) ?? Command.register(name, exec: artifact, params: parameters)
            if let description {
                Catalog.shared.update(reference) { descriptor in descriptor.description = description }
            }
            return reference
        }

        func harness(_ name: String, _ command: Reference, _ intent: Intent, _ parameters: [Harness.Parameter], description: String? = nil) -> Reference {
            let reference = existing(name, as: Harness.self) ?? Harness.register(name, command: command, intent: intent, parameters: parameters)
            if Harness.with(reference, { $0.command != command || $0.intent != intent || $0.parameters != parameters }) == true {
                Harness.update(reference) { $0 = Harness(reference, command: command, intent: intent, params: parameters) }
            }
            if let description {
                Catalog.shared.update(reference) { descriptor in descriptor.description = description }
            }
            return reference
        }

        let codex = artifact("Codex CLI", URL(fileURLWithPath: "/opt/homebrew/bin/codex"))

        /// The shape every codex invocation shares: stream JSON, no colour, no git assumptions.
        let base: [Command.Parameter] = [
            .fixed(.string("exec")),
            .fixed(.string("--json")),
            .fixed(.string("--color")),
            .fixed(.string("never")),
            .fixed(.string("--skip-git-repo-check"))
        ]

        /// Reaching back into the space that spawned it. The bearer token is the context id the
        /// daemon expands from the environment, so a subprocess can only ever address its own space.
        let connected: [Command.Parameter] = [
            .fixed(.string("-c")),
            .fixed(.string("mcp_servers.scint.url=\(endpoint)")),
            .fixed(.string("-c")),
            .fixed(.string("mcp_servers.scint.bearer_token_env_var=SCINT_CONTEXT"))
        ]

        // MARK: - Commands

        let orchestrate = command(
            "Codex Orchestrate",
            codex,
            base + connected + [
                .fixed(.string("--dangerously-bypass-approvals-and-sandbox"))
            ],
            description: "Run codex against the space with its tools reachable and its thread kept, for work that spans a cluster."
        )

        let execute = command(
            "Codex Execute",
            codex,
            base + connected + [
                .fixed(.string("--dangerously-bypass-approvals-and-sandbox")),
                .fixed(.string("--ephemeral"))
            ],
            description: "Run codex with the space's interfaces reachable and no persisted thread, for carrying out a request and reporting the result."
        )

        let retrieve = command(
            "Codex Retrieve",
            codex,
            base + [
                .fixed(.string("-c")),
                .fixed(.string("tools.web_search=true")),
                .fixed(.string("--ephemeral")),
                .fixed(.string("-c")),
                .fixed(.string("sandbox_mode=read-only"))
            ],
            description: "Run codex with live web search and no space access, for finding things and reporting what was found."
        )

        let composer = harness(
            "Cluster Composer",
            orchestrate,
            .compose,
            [.argument(name: "input", type: .string(""), required: true, default: nil)],
            description: "Look across this space's cluster — what it holds, what is running, what has stalled — and act on the shape of it rather than the contents."
        )

        let dispatcher = harness(
            "Tool Dispatcher",
            execute,
            .dispatch,
            [.argument(name: "input", type: .string(""), required: true, default: nil)],
            description: "Carry out a request using this space's interfaces and report only the result, keeping the traffic of getting there out of everyone else's context."
        )

        let searcher = harness(
            "Web Searcher",
            retrieve,
            .search,
            [.argument(name: "input", type: .string(""), required: true, default: nil)],
            description: "Find what is relevant to a request, out on the web rather than in this space, and report the findings without the searching."
        )

        return References(
            orchestrate: orchestrate,
            execute: execute,
            retrieve: retrieve,
            composer: composer,
            dispatcher: dispatcher,
            searcher: searcher
        )
    }
}
