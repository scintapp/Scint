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
        let schedulerHarness: Reference
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

        let schedulerHarness = harness(
            "Scheduler",
            command(
                "Cron Observer",
                sh,
                [
                    .fixed(.string("-c")),
                    .fixed(.string(
                        #"""
                        operation="install"
                        schedule=""
                        repeats="false"

                        while [ "$#" -gt 0 ]; do
                            case "$1" in
                                --operation) operation="$2"; shift 2 ;;
                                --schedule) schedule="$2"; shift 2 ;;
                                --repeat) repeats="$2"; shift 2 ;;
                                *) echo "Unknown Observer argument: $1" >&2; exit 64 ;;
                            esac
                        done

                        marker="# scint-observer:${SCINT_CONTEXT}"
                        current=$(/usr/bin/crontab -l 2>/dev/null || true)
                        filtered=$(printf '%s\n' "$current" | /usr/bin/grep -Fv "$marker" || true)

                        if [ "$operation" = "remove" ]; then
                            printf '%s\n' "$filtered" | /usr/bin/crontab -
                            exit $?
                        fi

                        [ "$operation" = "install" ] || { echo "Observer operation must be install or remove." >&2; exit 64; }
                        [ -n "$schedule" ] || { echo "Observer schedule is required." >&2; exit 64; }
                        [ -n "$SCINT_ACTION" ] || { echo "Observer action is required." >&2; exit 64; }
                        [ -n "$SCINT_ACTION_REF" ] || { echo "Observer action reference is required." >&2; exit 64; }

                        set -f
                        old_ifs=$IFS
                        IFS=' '
                        set -- $schedule
                        IFS=$old_ifs
                        [ "$#" -eq 5 ] || { echo "Observer schedule must contain five cron fields." >&2; exit 64; }

                        case "$SCINT_ACTION" in
                            dispatch) callback="scint://dispatch?command=${SCINT_ACTION_REF}&arguments=%7B%7D" ;;
                            trigger) callback="scint://trigger?descriptor=${SCINT_ACTION_REF}" ;;
                            run) callback="scint://run?artifact=${SCINT_ACTION_REF}" ;;
                            *) echo "Observer action is invalid." >&2; exit 64 ;;
                        esac
                        if [ -n "$SCINT_TARGET" ]; then callback="${callback}&target=${SCINT_TARGET}"; fi

                        quote() {
                            escaped=$(printf '%s' "$1" | /usr/bin/sed "s/'/'\\\\''/g")
                            printf "'%s'" "$escaped"
                        }

                        action="/usr/bin/open -gj $(quote "$callback")"
                        cleanup="(/usr/bin/crontab -l 2>/dev/null | /usr/bin/grep -Fv $(quote "$marker") || true) | /usr/bin/crontab -"
                        if [ "$repeats" = "false" ]; then action="$action; $cleanup"; fi

                        {
                            printf '%s\n' "$filtered"
                            printf '%s %s %s\n' "$schedule" "$action" "$marker"
                        } | /usr/bin/crontab -
                        """#
                    )),
                    .fixed(.string("scint-observer"))
                ]
            ),
            .observe,
            [
                .argument(
                    name: "operation",
                    type: .collection(["--operation": .sequence([.string("install"), .string("remove")])]),
                    required: false,
                    default: .collection(["--operation": .string("install")])
                ),
                .argument(
                    name: "schedule",
                    type: .collection(["--schedule": .string("")]),
                    required: false,
                    default: nil
                ),
                .argument(
                    name: "repeats",
                    type: .collection(["--repeat": .bool(false)]),
                    required: false,
                    default: .collection(["--repeat": .bool(false)])
                ),
                .target(
                    name: "target",
                    type: .anyReference,
                    default: nil
                ),
                .target(
                    name: "action",
                    type: .sequence([
                        .reference(Artifact.self),
                        .reference(Command.self),
                        .reference(Space.self),
                        .reference(Workspace.self)
                    ]),
                    default: nil
                )
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
            schedulerHarness: schedulerHarness
        )
    }
}
