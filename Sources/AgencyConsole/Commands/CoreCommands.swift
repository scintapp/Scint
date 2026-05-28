import Foundation


struct CoreCommandsAddon: CommandAddon {
    var commands: [AgencyCommand] {
        [
            AgencyCommand(
                path: [],
                documentation: CommandDocumentation(
                    path: [],
                    title: "AGENCY CONSOLE",
                    intro: ["Work with Agency runtime artifacts, commands, and harness from a command-line utility."],
                    usage: "agency <command> <subcommand> [flags]",
                    blocks: [
                        .list(title: "INTERFACE COMMANDS", entries: [
                            .init(term: "artifacts:", description: "Find and open artifact"),
                            .init(term: "commands:", description: "Explore and execute available commands"),
                            .init(term: "harness:", description: "Start a process using a harness")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for the given command"),
                            .init(term: "--search", description: "Search within the given command's scope")
                        ]),
                        .examples([
                            "agency artifacts list --search docs",
                            "agency artifacts open \"OpenAI Platform Docs\"",
                            "agency commands run curl --arg https://example.com",
                            "agency harness start \"Codex Harness\""
                        ])
                    ]
                ),
                handler: nil
            )
        ]
    }
}
