import Foundation


struct Manifest {
    static func load() async {
        let inbox = Space.new("Inbox")
        let drafts = Space.new("Drafts")
        let outlines = Space.new("Outlines")
        let spaces = Space.new("Spaces")

        Bridge.new("Drafts to Outlines", origin: drafts, to: outlines)
        Bridge.new("Outlines to Spaces", origin: outlines, to: spaces)
        Bridge.new("Spaces to Inbox", origin: spaces, to: inbox)

        let harnesses = Harnesses.load()
        let home = FileManager.default.homeDirectoryForCurrentUser

        func text(_ content: String) -> Material.Block { .text(UUID(), content) }
        func task(_ content: String, _ done: Bool = false) -> Material.Block { .task(UUID(), content, done) }

        @discardableResult
        func material(_ origin: Reference, _ name: String, _ blocks: [Material.Block]) -> Reference {
            let ref = Material.new(origin, name: name)
            Material.update(ref) { $0.insert(blocks, at: nil) }
            return ref
        }

        func artifact(_ name: String, _ path: String) -> Reference {
            Runtime.shared.all(as: Artifact.self).first { $0.0.descriptor.name == name }?.0
                ?? Artifact.new(name, home.appendingPathComponent(path))
        }

        func space(_ name: String, harness: Reference, artifacts: [Reference], in origin: Reference) -> Reference {
            let ref = Space.new(origin, name: name)
            Space.update(ref) { $0.harness = harness }
            for artifact in artifacts { Space.with(ref) { $0.add(artifact) } }
            return ref
        }

        func give(_ outline: Reference, to targets: [Reference]) {
            for target in targets { Space.with(target) { $0.add(outline) } }
        }

        // Spaces

        let scintRepo = artifact("Scint", "Developer/Scint")
        let dewRepo = artifact("Dew", "Developer/Dew")
        let voiceGuide = artifact("Voice Guide", "Developer/Voice/VOICE-GUIDE.md")
        let llmTics = artifact("LLM Tics", "Developer/Voice/LLM-TICS.md")
        let published = artifact("Published Articles", "Documents/Content/Published")
        let contentDrafts = artifact("Content Drafts", "Documents/Content/Drafts")
        let books = artifact("Books", "Documents/Knowledge/Books")

        let scint = space("Scint", harness: harnesses.evaluate, artifacts: [scintRepo], in: spaces)
        let runtime = space("Runtime", harness: harnesses.evaluate, artifacts: [], in: scint)
        space("Studio", harness: harnesses.compose, artifacts: [], in: scint)
        let dew = space("Dew", harness: harnesses.evaluate, artifacts: [dewRepo], in: spaces)
        let voice = space("Voice Study", harness: harnesses.compose, artifacts: [voiceGuide, llmTics], in: spaces)
        let writing = space("Writing", harness: harnesses.compose, artifacts: [published, contentDrafts], in: spaces)
        let reading = space("Parser", harness: harnesses.search, artifacts: [books], in: spaces)

        // Inbox

        material(inbox, "Dew for observers", [
            text("Could the scheduled observer harnesses lean on dew instead of their own launchd plumbing? It already wraps `claude -p` on a schedule and survives reboots.")
        ])
        material(inbox, "Statecharts", [
            text("Harel's statecharts paper keeps coming up. Composition state is basically a flat statechart right now: inactive, active, working, completed, failed."),
            text("Nested states might be how a space's lifecycle (Searcher → Evaluator → Observer) gets expressed without a scheduler.")
        ])
        material(inbox, "Headline", [
            text("\"The environment is the agent\" might be the headline, not the subtitle.")
        ])
        material(inbox, "Banana bread", [
            text("Two very brown bananas on the counter. Friday.")
        ])

        // Drafts

        let environment = material(drafts, "The Environment Is the Agent", [
            text("Most agent tools start from a chat and ask you to rebuild the world around it every time. The context is something you pass along, and it's gone by the next message."),
            text("Scint starts from a place instead. A space holds its documents, its tools, and a record of everything it has done. Swap the harness and the space keeps its memory; only the mind changes."),
            text("The claim I want to defend: context isn't an input to the agent. It's where the agent lives."),
            text("- spaces as desks, not prompts\n- harnesses as life stages\n- coordination through shared objects, not messages")
        ])
        let agency = material(drafts, "What Agency Does", [
            text("Agency is the difference between a tool that answers and a tool that owns an outcome."),
            text("Owning an outcome means knowing what's in reach, what's off limits, and what \"done\" looks like. None of that fits in a system prompt, but all of it fits in a room."),
            task("Find a better example than email triage"),
            task("Cut the second paragraph in half")
        ])
        material(drafts, "Why Outlines, Not Mandates", [
            text("If the structure carries the guardrails, the instructions can stay short. A space that only has read access to the published folder can't wander off and rewrite it."),
            text("That's the bet: give an agent an outline, not a seventy-page mandate, and let the room do the rest.")
        ])
        material(drafts, "Backtracking", [
            text("Language Agent Tree Search treats a run as a tree you can back out of. A forked space at a transcript point is the same idea with a filing cabinet attached."),
            text("- fork on failure, not on every step\n- keep the losing branch as an artifact")
        ])
        material(drafts, "Tics to Cut", [
            text("Patterns that make a draft read as generated:"),
            text("- stacked em-dash asides\n- \"it's not X, it's Y\" reversals\n- triplets for rhythm\n- closing on a rhetorical question"),
            task("Turn this into a checklist for Voice Study", true)
        ])
        material(drafts, "Dew Roadmap", [
            text("Small list, mostly polish."),
            task("Human-readable schedule in `dew list`", true),
            task("Log rotation for long-running jobs"),
            task("A `dew run --now` for testing a job without waiting")
        ])

        // Outlines

        let essay = material(outlines, "Finish the Agency Essay", [
            text("**Outcome:** a publishable draft of \"The Environment Is the Agent\", around 1,500 words."),
            text("Pull from the drafts below. Keep the voice guide's rules on openings, and run the tics checklist before handing anything back."),
            .material(environment),
            .material(agency),
            .artifact(voiceGuide),
            .artifact(llmTics),
            task("Outline sections from the two drafts", true),
            task("Write the opening"),
            task("First full draft"),
            task("Tics pass")
        ])
        give(essay, to: [writing, voice])

        let audit = material(outlines, "Voice Audit", [
            text("**Outcome:** a short report on where the published pieces drift from the voice guide."),
            text("Read only. Sample ten articles, cite the lines, and don't rewrite anything."),
            .artifact(published),
            .artifact(voiceGuide),
            task("Pick the ten articles", true),
            task("Score each against Part 7"),
            task("Summarize the three most common drifts")
        ])
        give(audit, to: [voice])

        let observers = material(outlines, "Dew as the Scheduler", [
            text("**Outcome:** scheduled observer harnesses run through dew instead of custom launchd scripts."),
            text("Compare what the observe scripts do today with what `dew add` already covers. Propose the smallest change on the Scint side."),
            .artifact(dewRepo),
            .artifact(scintRepo),
            task("List what the schedule script handles"),
            task("Map each piece to a dew command"),
            task("Prototype one observer on dew")
        ])
        give(observers, to: [dew, scint])

        let persistence = material(outlines, "Persistence Review", [
            text("**Outcome:** a list of the places where a missing ref crashes instead of coming back empty."),
            text("Focus on descriptor lookups and the space save path. Findings only, no fixes."),
            task("Trace `Runtime.get` callers", true),
            task("Check `Workspaces.save` with a deleted space"),
            task("Write up findings")
        ])
        give(persistence, to: [runtime])

        let readingList = material(outlines, "Agents and Search Parser", [
            text("**Outcome:** one page of notes connecting tree search, information retrieval, and statecharts to how spaces run."),
            .artifact(books),
            task("Language Agent Tree Search"),
            task("Statecharts"),
            task("Introduction to Information Retrieval, chapters 1–3")
        ])
        give(readingList, to: [reading])

        material(outlines, "Drafts Grid Polish", [
            text("**Outcome:** the drafts grid feels finished enough to use daily."),
            task("Dim drafts that an outline already references"),
            task("Keyboard selection"),
            task("Empty state")
        ])
    }
}

enum SampleInterfaces {
    struct References {
        let curl: Reference
        let sh: Reference
        let bash: Reference
        let fish: Reference
        let zsh: Reference
        let desktopFolder: Reference
        let anthropicDocs: Reference
        let openAIDocs: Reference
        let anthropicMessages: Reference
        let mistralMessages: Reference
        let openAIResponses: Reference
        let concatSwiftRepo: Reference
        let searchTextFiles: Reference
        let inspectFileMetadata: Reference
        let fetchURLHeaders: Reference
        let assistantHarness: Reference
        let composer: Reference
        let dispatcher: Reference
        let searcher: Reference
        let claudeCodeHarness: Reference
        let codexHarness: Reference
    }

    @discardableResult
    static func load() -> References {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        let mcpExecutable = Bundle.main.executableURL?.path ?? "/Applications/Scint.app/Contents/MacOS/Scint"
        let claudeMCPData = try? JSONSerialization.data(withJSONObject: [
            "mcpServers": [
                "scint": [
                    "type": "stdio",
                    "command": mcpExecutable,
                    "args": ["--mcp"]
                ]
            ]
        ])
        let claudeMCPConfig = claudeMCPData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        func exists<T: Resolvable>(_ name: String, as type: T.Type) -> Reference? {
            Runtime.shared.all(as: type).first { $0.0.descriptor.name == name }?.0
        }

        func artifact(_ name: String, _ url: URL) -> Reference {
            exists(name, as: Artifact.self) ?? Artifact.new(name, url)
        }

        func command(_ name: String, _ artifact: Reference, _ parameters: [Command.Parameter], description: String? = nil) -> Reference {
            let reference = exists(name, as: Command.self) ?? Command.new(name, exec: artifact, params: parameters)
            if let description {
                Catalog.shared.update(reference) { descriptor in descriptor.description = description }
            }
            return reference
        }

        func harness(_ name: String, _ command: Reference, _ intent: Intent, _ parameters: [Harness.Parameter], description: String? = nil) -> Reference {
            let reference = exists(name, as: Harness.self) ?? Harness.register(name, command: command, intent: intent, parameters: parameters)
            if Harness.with(reference, { $0.command != command || $0.intent != intent || $0.parameters != parameters }) == true {
                Harness.update(reference) { $0 = Harness(reference, command: command, intent: intent, params: parameters) }
            }
            if let description {
                Catalog.shared.update(reference) { descriptor in descriptor.description = description }
            }
            return reference
        }

        let sh = artifact("sh", URL(fileURLWithPath: "/bin/sh"))
        let bash = artifact("bash", URL(fileURLWithPath: "/bin/bash"))
        let fish = artifact("fish", URL(fileURLWithPath: "/opt/homebrew/bin/fish"))
        let zsh = artifact("zsh", URL(fileURLWithPath: "/bin/zsh"))
        let curl = artifact("curl", URL(fileURLWithPath: "/usr/bin/curl"))
        let grep = artifact("grep", URL(fileURLWithPath: "/usr/bin/grep"))
        let mdls = artifact("mdls", URL(fileURLWithPath: "/usr/bin/mdls"))
        let env = artifact("env", URL(fileURLWithPath: "/usr/bin/env"))

        let anthropicDocs = artifact("Claude Platform Docs", URL(string: "https://platform.claude.com/docs/en/home")!)
        let openAIDocs = artifact("OpenAI Platform Docs", URL(string: "https://platform.openai.com/docs")!)
        let desktopFolder = artifact("Desktop", home.appendingPathComponent("Desktop", isDirectory: true))

        let concatScript = artifact(
            "Concat Swift Repo Script",
            home.appendingPathComponent("Developer/Scripts/Concat.swift")
        )

        let concatSwiftRepo = command(
            "Concat Swift Repo",
            env,
            [
                .fixed(.string("swift")),
                .fixed(.reference(concatScript)),
                .argument(name: "directory", type: .string(""), required: true),
                .argument(name: "output", type: .string(""), required: false, default: nil)
            ],
            description: """
            Concatenate every Swift file below a directory into one annotated text file. \
            Takes the directory to scan and, optionally, the output file path — supply it, \
            since the default is relative to an unspecified working directory.
            """
        )

        let searchTextFiles = command(
            "Search Text Files",
            grep,
            [
                .fixed(.string("-R")),
                .fixed(.string("-n")),
                .fixed(.string("-I")),
                .fixed(.string("-e")),
                .argument(name: "query", type: .string(""), required: true),
                .argument(name: "path", type: .string(""), required: true)
            ],
            description: "Recursively search text files below a local path and return matching file names, line numbers, and lines."
        )

        let inspectFileMetadata = command(
            "Inspect File Metadata",
            mdls,
            [
                .argument(
                    name: "attribute",
                    type: .collection(["-name": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(name: "path", type: .string(""), required: true)
            ],
            description: "Inspect Spotlight metadata for a local file, optionally limiting output to one metadata attribute."
        )

        let fetchURLHeaders = command(
            "Fetch URL Headers",
            curl,
            [
                .fixed(.string("--fail-with-body")),
                .fixed(.string("--silent")),
                .fixed(.string("--show-error")),
                .fixed(.string("--location")),
                .fixed(.string("--head")),
                .fixed(.string("--max-time")),
                .fixed(.string("20")),
                .argument(name: "url", type: .string(""), required: true)
            ],
            description: "Follow redirects and return HTTP response headers for a URL with a twenty-second timeout."
        )

        let anthropicMessages = command(
            "Anthropic Messages",
            curl,
            [
                .fixed(.string("-sN")),
                .fixed(.string("https://api.anthropic.com/v1/messages")),
                .fixed(.string("-H")),
                .fixed(.string("Content-Type: application/json")),
                .fixed(.string("-H")),
                .fixed(.string("x-api-key: $ANTHROPIC_API_KEY")),
                .fixed(.string("-H")),
                .fixed(.string("anthropic-version: 2023-06-01")),
                .fixed(.string("-d")),
                .fixed(.string(#"{"model":"claude-sonnet-4-6","max_tokens":4096,"messages":[{"role":"user","content":"$PROMPT"}]}"#))
            ]
        )

        let openAIResponses = command(
            "OpenAI Responses",
            curl,
            [
                .fixed(.string("-sN")),
                .fixed(.string("https://api.openai.com/v1/responses")),
                .fixed(.string("-H")),
                .fixed(.string("Content-Type: application/json")),
                .fixed(.string("-H")),
                .fixed(.string("Authorization: Bearer $OPENAI_API_KEY")),
                .fixed(.string("-d")),
                .fixed(.string(#"{"model":"gpt-5.6","input":"$PROMPT"}"#))
            ]
        )

        let mistralMessages = command(
            "Mistral Messages",
            curl,
            [
                .fixed(.string("-sN")),
                .fixed(.string("https://api.mistral.ai/v1/chat/completions")),
                .fixed(.string("-H")),
                .fixed(.string("Content-Type: application/json")),
                .fixed(.string("Authorization: Bearer $MISTRAL_API_KEY")),
                .fixed(.string(#"{"model":"mistral-large-latest""gpt-5.6","input":"$PROMPT"}"#))
            ]
        )

        let assistantHarness = harness(
            "Scint Workspace Assistant",
            openAIResponses,
            .compose,
            [
                .argument(
                    name: "Model",
                    type: .collection(["--model": .sequence([
                        .string("gpt-5.6-sol"),
                        .string("gpt-5.6-terra"),
                        .string("gpt-5.6-luna"),
                        .string("gpt-5.5"),
                        .string("gpt-5.4"),
                        .string("gpt-5.4-mini")
                    ])]),
                    required: false,
                    default: .string("gpt-5.6-sol"),
                ),
                .argument(
                    name: "Reasoning Effort",
                    type: .collection(["-c": .collection(["model_reasoning_effort": .sequence([
                        .string("low"),
                        .string("medium"),
                        .string("high"),
                        .string("xhigh"),
                        .string("max"),
                        .string("ultra")
                    ])])]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "sandbox",
                    type: .collection(["--sandbox": .sequence([
                        .string("read-only"),
                        .string("workspace-write"),
                        .string("danger-full-access")
                    ])]),
                    required: false,
                    default: .collection(["--sandbox": .string("workspace-write")])
                ),
                .argument(
                    name: "input",
                    type: .string(""),
                    required: true,
                    default: nil
                )
            ],
            description: "Answer a request about this space and compose new material from it, leaving the result as documents in place."
        )

        let claudeCodeHarness = harness(
            "Claude Code Harness",
            command(
                "Claude Code Command",
                artifact(
                    "Claude Code CLI",
                    URL(fileURLWithPath: "/opt/homebrew/bin/claude")
                ),
                [
                    .fixed(.string("--print")),
                    .fixed(.string("--output-format")),
                    .fixed(.string("stream-json")),
                    .fixed(.string("--verbose")),
                    .fixed(.string("--mcp-config")),
                    .fixed(.string(claudeMCPConfig)),
                    .fixed(.string("--strict-mcp-config"))
                ]
            ),
            .evaluate,
            [
                .argument(
                    name: "model",
                    type: .collection(["--model": .sequence([
                        .string("claude-fable-5-1"),
                        .string("claude-opus-5"),
                        .string("claude-sonnet-5"),
                        .string("claude-haiku-4-5"),
                        .string("claude-opus-4-8")
                    ])]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "additionalDirectories",
                    type: .collection(["--add-dir": .sequence(.reference(Artifact.self))]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "reasoningEffort",
                    type: .collection(["--effort": .range([
                        .string("low"),
                        .string("medium"),
                        .string("high"),
                        .string("xhigh"),
                        .string("max")
                    ])]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "sandbox",
                    type: .collection(["--permission-mode": .sequence([
                        .string("default"),
                        .string("acceptEdits"),
                        .string("auto"),
                        .string("dontAsk"),
                        .string("plan"),
                        .string("bypassPermissions")
                    ])]),
                    required: false,
                    default: .collection(["--permission-mode": .string("default")])
                ),
                .argument(name: "input", type: .string(""), required: true, default: nil)
            ],
            description: "Evaluate a request against this space with Claude Code, reading its documents and calling its capabilities, and report what was found or done."
        )

        let codexHarness = harness(
            "Codex Harness",
            command(
                "Codex Exec",
                artifact(
                    "Codex CLI",
                    URL(fileURLWithPath: "/opt/homebrew/bin/codex")
                ),
                [
                    .fixed(.string("exec")),
                    .fixed(.string("--json")),
                    .fixed(.string("--color")),
                    .fixed(.string("never")),
                    .fixed(.string("--skip-git-repo-check")),
                    .fixed(.string("--dangerously-bypass-approvals-and-sandbox")),
                    .fixed(.string("-c")),
                    .fixed(.string("mcp_servers.scint.command=\"\(mcpExecutable)\"")),
                    .fixed(.string("-c")),
                    .fixed(.string("mcp_servers.scint.args=[\"--mcp\"]"))
                ]
            ),
            .evaluate,
            [
                .argument(
                    name: "model",
                    type: .collection(["--model": .sequence([
                        .string("gpt-6-astra"),
                        .string("gpt-5.6-sol"),
                        .string("gpt-5.6-terra"),
                        .string("gpt-5.6-luna"),
                        .string("gpt-5.5")
                    ])]),
                    required: false,
                    default: nil
                ),
                .argument(name: "directory", type: .collection(["-C": .reference(Artifact.self)]), required: false, default: nil),
                .argument(
                    name: "additionalDirectories",
                    type: .collection(["--add-dir": .sequence(.reference(Artifact.self))]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "reasoningEffort",
                    type: .collection(["-c": .collection(["model_reasoning_effort": .range([
                        .string("low"),
                        .string("medium"),
                        .string("high"),
                        .string("xhigh"),
                        .string("max"),
                        .string("ultra")
                    ])])]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "sandbox",
                    type: .collection(["--sandbox": .sequence([
                        .string("read-only"),
                        .string("workspace-write"),
                        .string("danger-full-access")
                    ])]),
                    required: false,
                    default: .collection(["--sandbox": .string("workspace-write")])
                ),
                .argument(name: "input", type: .string(""), required: true, default: nil)
            ],
            description: "Evaluate a request against this space, reading its documents and calling its capabilities, and report what was found or done."
        )

        let codexCommand = Harness.with(codexHarness, { $0.command })!
        let codexParameters = Harness.with(codexHarness, { $0.parameters })!

        let composer = harness(
            "Composer", codexCommand, .compose, codexParameters,
            description: "Draft and revise this space's documents — write new material, restructure what exists, and leave the result in place."
        )

        let dispatcher = harness(
            "Dispatcher", codexCommand, .dispatch, codexParameters,
            description: "Carry out a request by invoking this space's capabilities, and report their results."
        )

        let searcher = harness(
            "Searcher", codexCommand, .search, codexParameters,
            description: "Locate material relevant to a request and report where it is, without reading everything."
        )

        return References(
            curl: curl,
            sh: sh,
            bash: bash,
            fish: fish,
            zsh: zsh,
            desktopFolder: desktopFolder,
            anthropicDocs: anthropicDocs,
            openAIDocs: openAIDocs,
            anthropicMessages: anthropicMessages,
            mistralMessages: mistralMessages,
            openAIResponses: openAIResponses,
            concatSwiftRepo: concatSwiftRepo,
            searchTextFiles: searchTextFiles,
            inspectFileMetadata: inspectFileMetadata,
            fetchURLHeaders: fetchURLHeaders,
            assistantHarness: assistantHarness,
            composer: composer,
            dispatcher: dispatcher,
            searcher: searcher,
            claudeCodeHarness: claudeCodeHarness,
            codexHarness: codexHarness,
        )
    }
}

enum SampleData {
    static let interfaces = SampleInterfaces.load()

    @discardableResult
    static func load(_ space: Reference) async -> Bool {
        guard Space.with(space, { $0.spaces.isEmpty }) ?? true else { return false }

        let codexHarness = interfaces.codexHarness
        let mistralMessages = interfaces.mistralMessages
        let researchCommands = [
            interfaces.searchTextFiles,
            interfaces.inspectFileMetadata,
            interfaces.fetchURLHeaders,
            interfaces.concatSwiftRepo
        ]

        Space.update(space, { ws in
            let components = [
                mistralMessages, interfaces.codexHarness,
                interfaces.composer, interfaces.dispatcher,  interfaces.searcher
            ]
            for component in components { ws.add(component) }
            ws.name = "Scint"
        })

        func write(_ ref: Reference, title: String, body: [String], components: [Reference], tasks: [(String, Bool)]) {
            Material.update(ref) { material in
                material.insert(.text(.init(), "# \(title)"), at: nil)
                for paragraph in body {
                    material.insert(.text(.init(), paragraph), at: nil)
                }
                for component in components {
                    switch component.type {
                        case is Artifact.Type: material.insert(.artifact(component), at: nil)
                        case is Command.Type: material.insert(.command(component), at: nil)
                        case is Material.Type: material.insert(.material(component), at: nil)
                        default: break
                    }
                }
                for task in tasks {
                    material.insert(.task(.init(), task.0, task.1), at: nil)
                }
            }
        }

        @discardableResult
        func material(_ name: String, origin: Reference, title: String, body: [String], components: [Reference], tasks: [(String, Bool)]) -> Reference {
            let ref = Material.new(origin, name: name)
            write(ref, title: title, body: body, components: components, tasks: tasks)
            return ref
        }

        func configure(_ spaceRef: Reference, description: String, materials: [Reference], components: [Reference], harness: Reference? = nil) {
            Space.update(spaceRef) { space in
                space.description = description
                if let harness { space.harness = harness }
                for ref in materials + components { space.add(ref) }
            }
        }

        let contentStudio = Space.new("Content Studio", origin: space)
        let researchDesk = Space.new("Research Desk", origin: contentStudio)
        let contentProduction = Space.new("Content Production", origin: contentStudio)
        let editorialCalendar = Space.new("Editorial Calendar", origin: contentProduction)

        let editorialCharter = material(
            "Editorial System Charter",
            origin: contentProduction,
            title: "Editorial System Charter",
            body: [
                "This space runs a professional publishing practice where research notes become briefs, drafts, newsletters, and reusable clips.",
                "Agents may organize sources, extract claims, and draft options. They must preserve attribution and make uncertainty visible."
            ],
            components: [codexHarness],
            tasks: [
                ("Require source links for any claim that sounds empirical.", false),
                ("Keep personal opinion separate from sourced findings.", false),
                ("Store reusable examples after the operator approves them.", false)
            ]
        )

        let voiceRules = material(
            "Voice and Evidence Rules",
            origin: contentProduction,
            title: "Voice and Evidence Rules",
            body: [
                "Define the house style for content writing. The writing should be specific, grounded, and willing to leave rough edges where the operator needs to decide.",
                "Avoid generic thought-leadership phrasing. The strongest output should feel like a knowledgeable person organizing a real argument."
            ],
            components: [codexHarness],
            tasks: [
                ("Prefer concrete examples over category labels.", false),
                ("Preserve named sources and dates in research summaries.", false),
                ("Flag unsupported claims instead of smoothing them over.", true)
            ]
        )

        configure(
            contentProduction,
            description: "Research, drafting, and publishing process materials for a knowledge business.",
            materials: [editorialCharter, voiceRules],
            components: [codexHarness],
            harness: codexHarness
        )

        let researchBrief = material(
            "Research Brief Template",
            origin: researchDesk,
            title: "Research Brief Template",
            body: [
                "Turn a topic prompt into a research brief with a working question, audience context, source plan, and expected use of the finished work.",
            ],
            components: [codexHarness, interfaces.searchTextFiles, interfaces.fetchURLHeaders],
            tasks: [
                ("State the working question before collecting sources.", false),
                ("Limit initial source categories to primary, expert, and counterexample.", false),
                ("Name the intended output: essay, client memo, talk, or product note.", false)
            ]
        )

        let reliabilityNotes = material(
            "Source Reliability Notes",
            origin: researchDesk,
            title: "Source Reliability Notes",
            body: [
                "The output is a source ledger. It does not need to be elegant, but it needs to be traceable."
            ],
            components: [codexHarness, interfaces.inspectFileMetadata],
            tasks: [
                ("Record author, date, publisher, and reason for inclusion.", false),
                ("Mark sources that are useful for framing but weak as evidence.", false),
                ("Keep rejected sources with a short reason.", false)
            ]
        )

        configure(
            researchDesk,
            description: "Reusable research methods for source-led writing and strategic analysis.",
            materials: [researchBrief, reliabilityNotes],
            components: [codexHarness] + researchCommands,
            harness: codexHarness
        )

        let publishingCadence = material(
            "Publishing Cadence",
            origin: editorialCalendar,
            title: "Publishing Cadence",
            body: [
                "Maintain an editorial calendar that reflects actual production capacity. A calendar item is not ready just because it has a title. It needs a usable angle and source path."
            ],
            components: [codexHarness],
            tasks: [
                ("Mark each planned piece as idea, researched, drafted, or scheduled.", false),
                ("Prefer fewer stronger pieces over a crowded calendar.", true),
                ("Keep business launch dates visible beside editorial dates.", false)
            ]
        )

        let draftReadiness = material(
            "Draft Readiness Checklist",
            origin: editorialCalendar,
            title: "Draft Readiness Checklist",
            body: [
                "Before a draft run starts, check whether the piece has a clear reader, point of view, evidence base, and desired action.",
                "The process should return a readiness verdict. If not ready, it should recommend the smallest next action."
            ],
            components: [codexHarness],
            tasks: [
                ("Confirm reader, promise, evidence, and CTA.", false),
                ("List the missing item that most blocks drafting.", false),
                ("Do not produce a full draft from an unresolved angle.", false)
            ]
        )

        configure(
            editorialCalendar,
            description: "Planning materials that keep publishing tied to research readiness and business timing.",
            materials: [publishingCadence, draftReadiness],
            components: [codexHarness],
            harness: codexHarness
        )

        return true
    }
}
