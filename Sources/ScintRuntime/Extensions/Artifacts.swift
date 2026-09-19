import Foundation


enum Artifacts {
    struct References {}

    static func load() {
        Artifact.new("Codex CLI", URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        Artifact.new("dew", URL(fileURLWithPath: "/usr/local/bin/dew"))
    }
}
