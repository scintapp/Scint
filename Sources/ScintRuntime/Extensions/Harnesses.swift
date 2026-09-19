import Foundation


enum Harnesses {
    struct References {
        let compose: Reference
        let dispatch: Reference
        let evaluate: Reference
        let search: Reference
        let schedule: Reference
        let unschedule: Reference
    }

    @discardableResult
    static func load() -> References {
        func exists<T: Resolvable>(_ name: String, as type: T.Type) -> Reference? {
            Runtime.shared.all(as: type).first { $0.0.descriptor.name == name }?.0
        }

        func artifact(_ name: String, _ url: URL) -> Reference {
            Artifact.new(name, url)
        }

        func command(name: String, description: String, artifact: Reference, parameters: [Command.Parameter]) -> Reference {
            let ref = Command.new(name: name, artifact:artifact, parameters: parameters)
            Catalog.shared.update(ref) { descriptor in descriptor.description = description }
            return ref
        }

        func harness(name: String, description: String, command: Reference, intent: Intent, parameters: [Harness.Parameter]) -> Reference {
            let ref = Harness.register(name, command: command, intent: intent, parameters: parameters)
            Catalog.shared.update(ref) { descriptor in descriptor.description = description }
            return ref
        }

        let codex = artifact("Codex CLI", URL(fileURLWithPath: "/opt/homebrew/bin/codex"))

        let base: [Command.Parameter] = [
            .fixed(.string("exec")),
            .fixed(.string("--json")),
            .fixed(.string("--color")),
            .fixed(.string("never")),
            .fixed(.string("--skip-git-repo-check")),
            .fixed(.string("-c")),
            .fixed(.string("mcp_servers.scint.command=\"\(Bundle.main.executableURL?.path ?? "/Applications/Scint.app/Contents/MacOS/Scint")\"")),
            .fixed(.string("-c")),
            .fixed(.string("mcp_servers.scint.args=[\"--mcp\"]"))
        ]

        let evaluate = command(
            name: "Codex Evaluate",
            description: "Run codex with the space's interfaces reachable and no persisted thread, for carrying out a request and reporting the result.",
            artifact: codex,
            parameters: base + [
                .fixed(.string("--dangerously-bypass-approvals-and-sandbox")),
                .fixed(.string("--ephemeral"))
            ],
        )

        let compose = harness(
            name: "Compose",
            description: "Look across this space's cluster — what it holds, what is running, what has stalled — and act on the shape of it rather than the contents.",
            command: codex,
            intent: .compose,
            parameters: [.argument(name: "input", type: .string(""), required: true, default: nil)],
        )

        let dispatch = harness(
            name: "Dispatcher",
            description: "Carry out a request using this space's interfaces and report only the result, keeping the traffic of getting there out of everyone else's context.",
            command: evaluate,
            intent: .dispatch,
            parameters: [.argument(name: "input", type: .string(""), required: true, default: nil)]
        )

        let env = artifact("env", URL(fileURLWithPath: "/usr/bin/env"))

        let exec = command(
            name: "Exec",
            description: "Run another command as this one, so a harness can take whichever command is dropped in.",
            artifact: env,
            parameters: [.argument(name: "command", type: .reference(Command.self), required: true)]
        )

        let dew = artifact("dew", URL(fileURLWithPath: "/usr/local/bin/dew"))

        let schedule = command(
            name: Automation.schedule,
            description: "Schedule a command with launchd, once at a time or on a cron recurrence.",
            artifact: dew,
            parameters: [
                .fixed(.string("add")),
                .argument(name: "name", type: .string(""), required: true),
                .argument(name: "cron", type: .collection(["--cron": .string("")])),
                .argument(name: "at", type: .collection(["--at": .string("")])),
                .argument(name: "command", type: .collection(["--command": .string("")]), required: true),
                .fixed(.string("--json"))
            ]
        )

        let unschedule = command(
            name: Automation.unschedule,
            description: "Remove a scheduled job from launchd.",
            artifact: dew,
            parameters: [
                .fixed(.string("remove")),
                .argument(name: "name", type: .string(""), required: true),
                .fixed(.string("--force")),
                .fixed(.string("--json"))
            ]
        )

        let search = harness(
            name: "Web Searcher",
            description: "Find what is relevant to a request, out on the web rather than in this space, and report the findings without the searching.",
            command: codex,
            intent: .search,
            parameters: [.argument(name: "input", type: .string(""), required: true, default: nil)],
        )

        return References(
            compose: compose,
            dispatch: dispatch,
            evaluate: evaluate,
            search: search,
            schedule: schedule,
            unschedule: unschedule,
        )
    }
}
