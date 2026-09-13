import Foundation


/// Observe-intent interfaces.
///
/// An observer is not a thing the runtime implements — it is an existing command-line tool that
/// blocks and prints, wrapped in enough of the argument grammar to configure it. The waiting, the
/// recurrence, and the predicate all live in the tool and its flags; nothing here needs a Swift
/// vocabulary of its own.
///
/// Two shapes of argument reach the UI, and the difference is not cosmetic. A single-key
/// `.collection` is flattened by `Renderer.value` into one `key=value` argv element, so it only
/// suits tools that accept GNU-style `--flag=value` — `fswatch` does, `curl` does not. Anything
/// that needs `--flag value` as two elements belongs in the command as `.fixed` pairs, with the
/// variable part left bare and positional.
enum ObserveInterfaces {
    struct References {
        let fswatch: Reference
        let scheduleScript: Reference
        let endpointScript: Reference
        let watchPaths: Reference
        let waitUntil: Reference
        let pollEndpoint: Reference
        let directoryObserver: Reference
        let scheduledObserver: Reference
        let endpointObserver: Reference
    }

    /// Where the shell observers live. They are ordinary files, registered as artifacts, and the
    /// commands below pass them to `/bin/sh` the same way the sample data passes Concat.swift to
    /// `swift`.
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

        let endpointScript = artifact(
            "Endpoint Observer Script",
            scripts.appendingPathComponent("observe-endpoint.sh")
        )

        // MARK: - Commands

        let watchPaths = command(
            "Watch Paths",
            fswatch,
            [.fixed(.string("-r"))],
            description: "Watch a path and print every file that changes beneath it, one per line, until stopped."
        )

        let waitUntil = command(
            "Wait Until",
            sh,
            [.fixed(.reference(scheduleScript))],
            description: "Wait for a wall-clock time, run something, and optionally keep doing it on a recurrence."
        )

        let pollEndpoint = command(
            "Poll Endpoint",
            sh,
            [.fixed(.reference(endpointScript))],
            description: "Poll a URL on an interval and report only when a jq predicate holds."
        )

        // MARK: - Harnesses

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
                    name: "latency",
                    type: .collection(["--latency": .range([
                        .string("0.5"),
                        .string("1"),
                        .string("5"),
                        .string("15"),
                        .string("60")
                    ])]),
                    required: false,
                    default: .collection(["--latency": .string("1")])
                ),
                // fswatch takes its path positionally, so this stays bare and is declared last.
                .argument(
                    name: "path",
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
                    name: "at",
                    type: .collection(["--at": .date(.distantPast)]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "every",
                    type: .collection(["--every": .sequence([
                        .string("once"),
                        .string("hourly"),
                        .string("daily"),
                        .string("weekly")
                    ])]),
                    required: false,
                    default: .collection(["--every": .string("once")])
                ),
                .argument(
                    name: "run",
                    type: .collection(["--run": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "label",
                    type: .collection(["--label": .string("")]),
                    required: false,
                    default: .collection(["--label": .string("Scheduled")])
                ),
                .argument(
                    name: "times",
                    type: .collection(["--times": .range([
                        .string("0"),
                        .string("1"),
                        .string("5"),
                        .string("25")
                    ])]),
                    required: false,
                    default: .collection(["--times": .string("0")])
                )
            ],
            description: "Wait until a given time, then act — once, or on an hourly, daily, or weekly recurrence."
        )

        let endpointObserver = harness(
            "Endpoint Observer",
            pollEndpoint,
            .observe,
            [
                .argument(
                    name: "url",
                    type: .collection(["--url": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "check",
                    type: .collection(["--check": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "report",
                    type: .collection(["--report": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "interval",
                    type: .collection(["--interval": .range([
                        .string("15"),
                        .string("60"),
                        .string("300"),
                        .string("900"),
                        .string("3600")
                    ])]),
                    required: false,
                    default: .collection(["--interval": .string("60")])
                ),
                .argument(
                    name: "label",
                    type: .collection(["--label": .string("")]),
                    required: false,
                    default: .collection(["--label": .string("Endpoint")])
                ),
                .argument(
                    name: "times",
                    type: .collection(["--times": .range([
                        .string("0"),
                        .string("1"),
                        .string("5"),
                        .string("25")
                    ])]),
                    required: false,
                    default: .collection(["--times": .string("0")])
                )
            ],
            description: "Poll a URL and speak only when a condition holds, expressed as a jq filter over the response."
        )

        return References(
            fswatch: fswatch,
            scheduleScript: scheduleScript,
            endpointScript: endpointScript,
            watchPaths: watchPaths,
            waitUntil: waitUntil,
            pollEndpoint: pollEndpoint,
            directoryObserver: directoryObserver,
            scheduledObserver: scheduledObserver,
            endpointObserver: endpointObserver
        )
    }
}
