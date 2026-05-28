import Foundation


enum RemindersDocumentation {
    static let root = CommandDocumentation(
        path: ["reminders"],
        title: "AGENCY / REMINDERS",
        intro: [
            "Work with tasks and task lists using the Reminders app on macOS. Pairs well with coffee and unrealistic self-expectations.",
            "Note: the Reminders integration runs through macOS automation APIs. Yes, really. It works great. Please don't ask."
        ],
        usage: "agency reminders <command> [flags]",
        blocks: [
            .list(title: "AVAILABLE COMMANDS", entries: [
                .init(term: "create:", description: "Create a new reminder or reminder list"),
                .init(term: "view:", description: "View reminders and reminder lists"),
                .init(term: "update:", description: "Modify an existing reminder"),
                .init(term: "complete:", description: "Mark one or more reminders as complete"),
                .init(term: "delete:", description: "Delete a reminder (no take-backs)")
            ]),
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Target a specific list by name"),
                .init(term: "--due", description: "Filter or set by due date"),
                .init(term: "--priority", description: "Filter or set priority: low, medium, high")
            ]),
            .examples([
                "agency reminders view --list \"Projects\" --priority high",
                "agency reminders create \"water the plants\" --priority high",
                "agency reminders update \"submit pr\" --due friday"
            ])
        ]
    )

    static let create = CommandDocumentation(
        path: ["reminders", "create"],
        title: "AGENCY / REMINDERS / CREATE",
        intro: [
            "Create a reminder in an existing list or create a new list if you only pass `--list`."
        ],
        usage: "agency reminders create [title] [flags]",
        blocks: [
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Target list for the new reminder, or create that list when no title is provided"),
                .init(term: "--due", description: "Due date such as `today`, `tomorrow`, `friday`, or `2026-03-13`"),
                .init(term: "--priority", description: "Priority for the reminder: low, medium, high"),
                .init(term: "--notes", description: "Optional notes to attach to the reminder"),
                .init(term: "--url", description: "Optional URL to associate with the reminder")
            ]),
            .examples([
                "agency reminders create \"water the plants\" --priority high",
                "agency reminders create \"submit taxes\" --list \"Projects\" --due friday",
                "agency reminders create --list \"Errands\""
            ])
        ]
    )

    static let view = CommandDocumentation(
        path: ["reminders", "view"],
        title: "AGENCY / REMINDERS / VIEW",
        intro: [
            "View reminder lists and active tasks without spelunking through the Reminders UI."
        ],
        usage: "agency reminders view [flags]",
        blocks: [
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Limit results to a specific list"),
                .init(term: "--due", description: "Filter by due date"),
                .init(term: "--priority", description: "Filter by priority: low, medium, high"),
                .init(term: "--search", description: "Filter by title or notes text"),
                .init(term: "--all", description: "Include completed reminders")
            ]),
            .examples([
                "agency reminders view",
                "agency reminders view --list \"Projects\" --priority high",
                "agency reminders view --due today --search invoice"
            ])
        ]
    )

    static let update = CommandDocumentation(
        path: ["reminders", "update"],
        title: "AGENCY / REMINDERS / UPDATE",
        intro: [
            "Modify an existing reminder by title match or identifier."
        ],
        usage: "agency reminders update <reminder> [flags]",
        blocks: [
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Limit the search to a specific list"),
                .init(term: "--title", description: "Replace the reminder title"),
                .init(term: "--notes", description: "Replace the reminder notes"),
                .init(term: "--due", description: "Set the due date; use `none` to clear it"),
                .init(term: "--priority", description: "Set priority: none, low, medium, high")
            ]),
            .examples([
                "agency reminders update \"submit pr\" --due friday",
                "agency reminders update \"buy beans\" --priority low --notes \"for Saturday\""
            ])
        ]
    )

    static let complete = CommandDocumentation(
        path: ["reminders", "complete"],
        title: "AGENCY / REMINDERS / COMPLETE",
        intro: [
            "Mark one or more reminders as complete."
        ],
        usage: "agency reminders complete <reminder> [<reminder> ...] [flags]",
        blocks: [
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Limit the search to a specific list")
            ]),
            .examples([
                "agency reminders complete \"submit pr\"",
                "agency reminders complete \"buy milk\" \"buy bread\" --list Errands"
            ])
        ]
    )

    static let delete = CommandDocumentation(
        path: ["reminders", "delete"],
        title: "AGENCY / REMINDERS / DELETE",
        intro: [
            "Delete a reminder permanently. The command name is honest because life is short."
        ],
        usage: "agency reminders delete <reminder> [flags]",
        blocks: [
            .list(title: "FLAGS", entries: [
                .init(term: "--list", description: "Limit the search to a specific list")
            ]),
            .examples([
                "agency reminders delete \"old grocery list\""
            ])
        ]
    )
}
