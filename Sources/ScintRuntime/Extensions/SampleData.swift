import Foundation


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
        let claudeCodeHarness: Reference
        let codexHarness: Reference
    }

    @discardableResult
    static func load() -> References {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()

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

        func harness(_ name: String, _ command: Reference, _ intent: Harness.Intent, _ parameters: [Harness.Parameter]) -> Reference {
            existing(name, as: Harness.self) ?? Harness.register(name, command: command, intent: intent, parameters: parameters)
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
                    name: "model",
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
                    name: "reasoningEffort",
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
                    name: "continuation",
                    type: .collection(["resume": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "prompt",
                    type: .string(""),
                    required: true,
                    default: nil
                )
            ]
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
                    .fixed(.string("--verbose"))
                ]
            ),
            .evaluate,
            [
                .argument(
                    name: "model",
                    type: .collection(["--model": .sequence([
                        .string("opus"),
                        .string("sonnet"),
                        .string("haiku")
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
                    type: .collection(["--effort": .sequence([
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
                .argument(name: "continuation", type: .collection(["--resume": .string("")]), required: false, default: nil),
                .argument(name: "prompt", type: .string(""), required: true, default: nil)
            ]
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
                    .fixed(.string("--dangerously-bypass-approvals-and-sandbox"))
                ]
            ),
            .evaluate,
            [
                .argument(
                    name: "model",
                    type: .collection(["--model": .sequence([
                        .string("gpt-5.6-sol"),
                        .string("gpt-5.6-terra"),
                        .string("gpt-5.6-luna"),
                        .string("gpt-5.5"),
                        .string("gpt-5.4"),
                        .string("gpt-5.4-mini")
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
                .argument(name: "continuation", type: .collection(["resume": .string("")]), required: false, default: nil),
                .argument(name: "prompt", type: .string(""), required: true, default: nil)
            ]
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
            claudeCodeHarness: claudeCodeHarness,
            codexHarness: codexHarness,
        )
    }
}

enum SampleData {
    static let interfaces = SampleInterfaces.load()

    @discardableResult
    static func load(_ workspace: Reference, for key: ModelKey) async -> Bool {
        switch key {
            case .editor: await editor(workspace); return false
            case .studio: return await studio(workspace)
        }
    }

    static func assistant(_ workspace: Reference) async { }
    static func builder(_ workspace: Reference) async { }
    static func editor(_ workspace: Reference) async { }
    static func panels(_ workspace: Reference) async { }
    @discardableResult
    static func studio(_ workspace: Reference) async -> Bool {
        guard Workspace.with(workspace, { $0.spaces.isEmpty }) ?? true else { return false }

        let codexHarness = interfaces.codexHarness
        let assistantHarness = interfaces.assistantHarness
        let mistralMessages = interfaces.mistralMessages
        let researchCommands = [
            interfaces.searchTextFiles,
            interfaces.inspectFileMetadata,
            interfaces.fetchURLHeaders,
            interfaces.concatSwiftRepo
        ]


        Workspace.update(workspace, { ws in
            let components = [assistantHarness, mistralMessages]
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
        func material(_ name: String, owner: Reference, title: String, body: [String], components: [Reference], tasks: [(String, Bool)]) -> Reference {
            let ref = Material.new(owner, name: name)
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

        let contentStudio = Space.new("Content Studio", origin: workspace)
        let researchDesk = Space.new("Research Desk", origin: contentStudio)
        let contentProduction = Space.new("Content Production", origin: contentStudio)
        let editorialCalendar = Space.new("Editorial Calendar", origin: contentProduction)

        let editorialCharter = material(
            "Editorial System Charter",
            owner: contentProduction,
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
            owner: contentProduction,
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
            owner: researchDesk,
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
            owner: researchDesk,
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
            owner: editorialCalendar,
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
            owner: editorialCalendar,
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
