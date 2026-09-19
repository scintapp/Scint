import Foundation


enum Commands {
    static func load() {
        Command.new(
            name: "Codex Evaluate",
            description: "Run codex with the space's interfaces reachable and no persisted thread, for carrying out a request and reporting the result.",
            artifact: Artifact.new("Codex CLI", URL(fileURLWithPath: "/opt/homebrew/bin/codex")),
            parameters: [
                .fixed(.string("exec")),
                .fixed(.string("--json")),
                .fixed(.string("--color")),
                .fixed(.string("never")),
                .fixed(.string("--skip-git-repo-check")),
                .fixed(.string("-c")),
                .fixed(.string("--dangerously-bypass-approvals-and-sandbox")),
                .fixed(.string("--ephemeral")),
            ],
        )
        Command.new(
            name: "Exec",
            description: "Run another command as this one, so a harness can take whichever command is dropped in.",
            artifact: Artifact.new("env", URL(fileURLWithPath: "/usr/bin/env")),
            parameters: [.argument(name: "command", type: .reference(Command.self), required: true)]
        )
    }
}
