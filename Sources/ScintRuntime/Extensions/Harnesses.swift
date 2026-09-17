import Foundation


enum Harnesses {
    struct References {
        let compose: Reference
        let dispatch: Reference
        let evaluate: Reference
        let search: Reference
    }

    private static let endpoint = "http://127.0.0.1:7345/mcp"

    @discardableResult
    static func load() -> References {
        func exists<T: Resolvable>(_ name: String, as type: T.Type) -> Reference? {
            Runtime.shared.all(as: type).first { $0.0.descriptor.name == name }?.0
        }

        func artifact(_ name: String, _ url: URL) -> Reference {
            Artifact.register(name, url)
        }

        func command(name: String, description: String, artifact: Reference, parameters: [Command.Parameter]) -> Reference {
            let ref = Command.register(name, exec: artifact, params: parameters)
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
            .fixed(.string("mcp_servers.scint.url=\(endpoint)")),
            .fixed(.string("-c")),
            .fixed(.string("mcp_servers.scint.bearer_token_env_var=SCINT_CONTEXT"))
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
            search: search
        )
    }
}

enum ObserveHarnesses {
    struct References {
        let fswatch: Reference
        let scheduleScript: Reference
        let watchPaths: Reference
        let waitUntil: Reference
        let directoryObserver: Reference
        let scheduledObserver: Reference
    }

    static var scripts: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .appendingPathComponent("Developer/Scint/script", isDirectory: true)
    }

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

        let sh = artifact("sh", URL(fileURLWithPath: "/bin/sh"))
        let fswatch = artifact("fswatch", URL(fileURLWithPath: "/opt/homebrew/bin/fswatch"))

        let scheduleScript = artifact(
            "Schedule Observer Script",
            scripts.appendingPathComponent("observe-schedule.sh")
        )

        let watchPaths = command(
            "Watch Paths",
            fswatch,
            [.fixed(.string("-r")), .fixed(.string("--latency")), .fixed(.string("1"))],
            description: "Watch a path and print every file that changes beneath it, one per line, until stopped."
        )

        let waitUntil = command(
            "Wait Until",
            sh,
            [.fixed(.reference(scheduleScript))],
            description: "Wait for a wall-clock time, run something, and optionally keep doing it on a recurrence."
        )

        let directoryObserver = harness(
            "Directory Observer",
            watchPaths,
            .observe,
            [
                .argument(
                    name: "event",
                    type: .collection(["--event": .sequence([
                        .string("Created"),
                        .string("Updated"),
                        .string("Removed"),
                        .string("Renamed"),
                        .string("MovedTo")
                    ])]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "directory",
                    type: .string(""),
                    required: false,
                    default: .string(
                        FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Desktop", isDirectory: true)
                            .path(percentEncoded: false)
                    )
                )
            ],
            description: "Watch a folder and report every change beneath it as it happens."
        )

        let scheduledObserver = harness(
            "Scheduled Observer",
            waitUntil,
            .observe,
            [
                .argument(
                    name: "date",
                    type: .collection(["--date": .date(.distantPast)]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "time",
                    type: .collection(["--time": .date(.distantPast)]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "repeat",
                    type: .collection(["--every": .sequence([
                        .string("never"),
                        .string("hourly"),
                        .string("daily"),
                        .string("weekly")
                    ])]),
                    required: false,
                    default: .collection(["--every": .string("never")])
                ),
                .argument(
                    name: "command",
                    type: .reference(Command.self),
                    required: false,
                    default: nil
                )
            ],
            description: "Wait until a given time, then act — once, or on an hourly, daily, or weekly recurrence."
        )

        return References(
            fswatch: fswatch,
            scheduleScript: scheduleScript,
            watchPaths: watchPaths,
            waitUntil: waitUntil,
            directoryObserver: directoryObserver,
            scheduledObserver: scheduledObserver
        )
    }
}
