import Foundation


struct CoreCommandsAddon: CommandAddon {
    var commands: [AgencyCommand] {
        [
            AgencyCommand(
                path: [],
                documentation: CommandDocumentation(
                    path: [],
                    title: "AGENCY CONSOLE",
                    intro: [
                        "Work with Agency using a powerful console utility. Made for human beings, agents, and satanic leaf-tailed geckos."
                    ],
                    usage: "agency <command> <subcommand> [flags]",
                    blocks: [
                        .list(title: "CORE COMMANDS", entries: [
                            .init(term: "controls:", description: "Explore available capabilities and tools"),
                            .init(term: "library:", description: "Access docs and instructions")
                        ]),
                        .list(title: "INTERFACE COMMANDS", entries: [
                            .init(term: "browser:", description: "Interact with sites and online resources"),
                            .init(term: "calendar:", description: "Manage Agency calendar events"),
                            .init(term: "contacts:", description: "Manage Agency contacts"),
                            .init(term: "inbox:", description: "Manage Agency messages"),
                            .init(term: "notes:", description: "Annotate the present and recall the past"),
                            .init(term: "reminders:", description: "Manage and track tasks with Reminders"),
                            .init(term: "spotlight:", description: "Multiplexed, multifaceted search over everything")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for the given command"),
                            .init(term: "--search", description: "Search within the given command's scope")
                        ]),
                        .examples([
                            "agency context view --intentions",
                            "agency notes --search \"structuration theory\"",
                            "agency inbox view --unread"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["context"],
                documentation: CommandDocumentation(
                    path: ["context"],
                    title: "AGENCY / CONTEXT",
                    intro: [
                        "View and manage the current operating context for Agency and its runtime."
                    ],
                    usage: "agency context <command> [flags]",
                    blocks: [
                        .list(title: "AVAILABLE COMMANDS", entries: [
                            .init(term: "view:", description: "Inspect the current context state"),
                            .init(term: "set:", description: "Apply explicit context values"),
                            .init(term: "clear:", description: "Remove context values you no longer need")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command"),
                            .init(term: "--search", description: "Search context documentation")
                        ]),
                        .examples([
                            "agency context view --intentions"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["context", "view"],
                documentation: CommandDocumentation(
                    path: ["context", "view"],
                    title: "AGENCY / CONTEXT / VIEW",
                    intro: [
                        "Inspect the active context state available to Agency."
                    ],
                    usage: "agency context view [flags]",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--intentions", description: "Focus the view on current intentions"),
                            .init(term: "--help", description: "Show documentation for this command")
                        ]),
                        .examples([
                            "agency context view --intentions"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["interfaces"],
                documentation: CommandDocumentation(
                    path: ["interfaces"],
                    title: "AGENCY / INTERFACES",
                    intro: [
                        "Explore Agency interfaces, add-ons, and the capabilities they expose."
                    ],
                    usage: "agency interfaces <command> [flags]",
                    blocks: [
                        .list(title: "AVAILABLE COMMANDS", entries: [
                            .init(term: "view:", description: "List registered interfaces and their status"),
                            .init(term: "describe:", description: "Inspect a single interface in more detail")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command"),
                            .init(term: "--search", description: "Search interface documentation")
                        ]),
                        .examples([
                            "agency interfaces view"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["interfaces", "view"],
                documentation: CommandDocumentation(
                    path: ["interfaces", "view"],
                    title: "AGENCY / INTERFACES / VIEW",
                    intro: [
                        "List available interfaces and the surface area they expose."
                    ],
                    usage: "agency interfaces view [flags]",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command")
                        ]),
                        .examples([
                            "agency interfaces view"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["interfaces", "describe"],
                documentation: CommandDocumentation(
                    path: ["interfaces", "describe"],
                    title: "AGENCY / INTERFACES / DESCRIBE",
                    intro: [
                        "Inspect a single interface in more detail."
                    ],
                    usage: "agency interfaces describe <interface> [flags]",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command")
                        ]),
                        .examples([
                            "agency interfaces describe reminders"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["knowledge"],
                documentation: CommandDocumentation(
                    path: ["knowledge"],
                    title: "AGENCY / KNOWLEDGE",
                    intro: [
                        "Access docs, instructions, and the accumulated institutional memory."
                    ],
                    usage: "agency knowledge <command> [flags]",
                    blocks: [
                        .list(title: "AVAILABLE COMMANDS", entries: [
                            .init(term: "view:", description: "Read available documentation"),
                            .init(term: "search:", description: "Search docs and operational instructions")
                        ]),
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command"),
                            .init(term: "--search", description: "Search knowledge documentation")
                        ]),
                        .examples([
                            "agency knowledge search --search reminders"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["knowledge", "view"],
                documentation: CommandDocumentation(
                    path: ["knowledge", "view"],
                    title: "AGENCY / KNOWLEDGE / VIEW",
                    intro: [
                        "Read available documentation from the knowledge layer."
                    ],
                    usage: "agency knowledge view [flags]",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--help", description: "Show documentation for this command")
                        ]),
                        .examples([
                            "agency knowledge view"
                        ])
                    ]
                ),
                handler: nil
            ),
            AgencyCommand(
                path: ["knowledge", "search"],
                documentation: CommandDocumentation(
                    path: ["knowledge", "search"],
                    title: "AGENCY / KNOWLEDGE / SEARCH",
                    intro: [
                        "Search docs and instructions without rummaging through folders by hand."
                    ],
                    usage: "agency knowledge search --search <query>",
                    blocks: [
                        .list(title: "FLAGS", entries: [
                            .init(term: "--search", description: "Query to search within knowledge docs"),
                            .init(term: "--help", description: "Show documentation for this command")
                        ]),
                        .examples([
                            "agency knowledge search --search reminders"
                        ])
                    ]
                ),
                handler: nil
            )
        ]
    }
}
