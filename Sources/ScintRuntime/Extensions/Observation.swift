import Foundation


enum ObserveInterfaces {
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
