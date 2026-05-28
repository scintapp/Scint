import Foundation


struct CoreCommandsAddon: CommandAddon {
    var commands: [AgencyCommand] {
        [
            AgencyCommand(
                path: [],
                documentation: CommandDocumentation(
                    path: [],
                    title: "AGENCY CONSOLE",
                    intro: ["Work with Agency runtime artifacts, controls, and services from a command-line utility."],
                    usage: "agency <command> <subcommand> [flags]",
                    blocks: [
                        .list(title: "INTERFACE COMMANDS", entries: [
                            .init(term: "artifacts:", description: "List, inspect, and open runtime artifacts"),
                            .init(term: "controls:", description: "List, inspect, and run runtime controls"),
                            .init(term: "services:", description: "List, inspect, and start runtime services")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for the given command"),
                            .init(term: "--search", description: "Search within the given command's scope")
                        ]),
                        .examples([
                            "agency artifacts list --search docs",
                            "agency artifacts open \"OpenAI Platform Docs\"",
                            "agency controls run curl --arg https://example.com",
                            "agency services start \"Codex Harness\""
                        ])
                    ]
                ),
                handler: nil
            )
        ]
    }
}
