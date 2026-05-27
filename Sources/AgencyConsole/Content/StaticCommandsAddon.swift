import Foundation

struct StaticCommandsAddon: CommandAddon {
    var commands: [AgencyCommand] {
        [
            makeInterfaceCommand(
                name: "browser",
                summary: "Interact with sites and online resources.",
                examples: ["agency browser --help"]
            ),
            makeInterfaceCommand(
                name: "calendar",
                summary: "Manage Agency calendar events.",
                examples: ["agency calendar --help"]
            ),
            makeInterfaceCommand(
                name: "contacts",
                summary: "Manage Agency contacts.",
                examples: ["agency contacts --help"]
            ),
            makeInterfaceCommand(
                name: "inbox",
                summary: "Manage Agency messages.",
                examples: ["agency inbox view --unread"]
            ),
            makeInterfaceCommand(
                name: "notes",
                summary: "Annotate the present and recall the past.",
                examples: ["agency notes --search \"structuration theory\""]
            ),
            makeInterfaceCommand(
                name: "spotlight",
                summary: "Multiplexed, multifaceted search over everything.",
                examples: ["agency spotlight --search calendar"]
            )
        ].flatMap(makeCommands)
    }

    private func makeInterfaceCommand(name: String, summary: String, examples: [String]) -> StaticCommandDefinition {
        StaticCommandDefinition(
            name: name,
            summary: summary,
            examples: examples
        )
    }

    private func makeCommands(from definition: StaticCommandDefinition) -> [AgencyCommand] {
        var commands = [
            AgencyCommand(
                path: [definition.name],
                documentation: CommandDocumentation(
                    path: [definition.name],
                    title: "AGENCY / \(definition.name.uppercased())",
                    intro: [
                        definition.summary,
                        "This interface is staged in the command registry and ready for a real implementation when the add-on lands."
                    ],
                    usage: "agency \(definition.name) <command> [flags]",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command"),
                            .init(term: "--search", description: "Search documentation within this interface")
                        ]),
                        .examples(definition.examples)
                    ]
                ),
                handler: nil
            )
        ]

        if definition.name == "inbox" {
            commands.append(
                AgencyCommand(
                    path: ["inbox", "view"],
                    documentation: CommandDocumentation(
                        path: ["inbox", "view"],
                        title: "AGENCY / INBOX / VIEW",
                        intro: [
                            "Inspect inbox messages and filter down to what still needs attention."
                        ],
                        usage: "agency inbox view [flags]",
                        blocks: [
                            .list(title: "FLAGS", entries: [
                                .init(term: "--unread", description: "Limit the view to unread messages"),
                                .init(term: "--help", description: "Show documentation for this command")
                            ]),
                            .examples([
                                "agency inbox view --unread"
                            ])
                        ]
                    ),
                    handler: nil
                )
            )
        }

        return commands
    }
}

private struct StaticCommandDefinition {
    let name: String
    let summary: String
    let examples: [String]
}
