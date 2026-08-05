import Foundation


public enum SampleInterfaces {
    private static let observerScript = #"""
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

    marker="# Scint-observer:${Scint_CONTEXT}"
    current=$(/usr/bin/crontab -l 2>/dev/null || true)
    filtered=$(printf '%s\n' "$current" | /usr/bin/grep -Fv "$marker" || true)

    if [ "$operation" = "remove" ]; then
        printf '%s\n' "$filtered" | /usr/bin/crontab -
        exit $?
    fi

    [ "$operation" = "install" ] || { echo "Observer operation must be install or remove." >&2; exit 64; }
    [ -n "$schedule" ] || { echo "Observer schedule is required." >&2; exit 64; }
    [ -n "$Scint_ACTION" ] || { echo "Observer action is required." >&2; exit 64; }
    [ -n "$Scint_ACTION_REF" ] || { echo "Observer action reference is required." >&2; exit 64; }

    set -f
    old_ifs=$IFS
    IFS=' '
    set -- $schedule
    IFS=$old_ifs
    [ "$#" -eq 5 ] || { echo "Observer schedule must contain five cron fields." >&2; exit 64; }

    case "$Scint_ACTION" in
        dispatch) callback="Scint://dispatch?command=${Scint_ACTION_REF}&arguments=%7B%7D" ;;
        trigger) callback="Scint://trigger?descriptor=${Scint_ACTION_REF}" ;;
        run) callback="Scint://run?artifact=${Scint_ACTION_REF}" ;;
        *) echo "Observer action is invalid." >&2; exit 64 ;;
    esac
    if [ -n "$Scint_TARGET" ]; then callback="${callback}&target=${Scint_TARGET}"; fi

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

    public struct References {
        public let shell: Reference
        public let curl: Reference
        public let mdfind: Reference
        public let osascript: Reference
        public let documents: Reference
        public let downloads: Reference
        public let desktop: Reference
        public let openAIDocs: Reference
        public let stripeDocs: Reference
        public let analyticsHelp: Reference
        public let wcag: Reference
        public let notionAPI: Reference
        public let fetchPage: Reference
        public let searchLocalFiles: Reference
        public let folderInventory: Reference
        public let focusMode: Reference
        public let responses: Reference
        public let codex: Reference
        public let codexExec: Reference
        public let researchHarness: Reference
        public let evidenceHarness: Reference
        public let clientHarness: Reference
        public let indexHarness: Reference
        public let focusGuard: Reference
        public let codexHarness: Reference
        public let observerCommand: Reference
        public let observerHarness: Reference
    }

    @discardableResult
    public static func load() -> References {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()

        func existing<T: Resolvable>(_ name: String, as type: T.Type) -> Reference? {
            Runtime.shared.all(as: type).first { $0.0.descriptor.name == name }?.0
        }

        func artifact(_ name: String, _ url: URL) -> Reference {
            existing(name, as: Artifact.self) ?? Artifact.register(name, url)
        }

        func command(_ name: String, _ artifact: Reference, _ parameters: [Command.Parameter]) -> Reference {
            existing(name, as: Command.self) ?? Command.register(name, exec: artifact, params: parameters)
        }

        func harness(_ name: String, _ command: Reference, _ intent: Harness.Process, _ parameters: [Harness.Parameter]) -> Reference {
            existing(name, as: Harness.self) ?? Harness.register(name, command: command, intent: intent, parameters: parameters)
        }

        let sh = artifact("sh", URL(fileURLWithPath: "/bin/sh"))
        let curl = artifact("curl", URL(fileURLWithPath: "/usr/bin/curl"))
        let mdfind = artifact("mdfind", URL(fileURLWithPath: "/usr/bin/mdfind"))
        let osascript = artifact("osascript", URL(fileURLWithPath: "/usr/bin/osascript"))
        let documents = artifact("Documents", home.appendingPathComponent("Documents", isDirectory: true))
        let downloads = artifact("Downloads", home.appendingPathComponent("Downloads", isDirectory: true))
        let desktop = artifact("Desktop", home.appendingPathComponent("Desktop", isDirectory: true))
        let openAIDocs = artifact("OpenAI Platform Docs", URL(string: "https://platform.openai.com/docs")!)
        let stripeDocs = artifact("Stripe Docs", URL(string: "https://docs.stripe.com")!)
        let analyticsHelp = artifact("Google Analytics Help", URL(string: "https://support.google.com/analytics")!)
        let wcag = artifact("WCAG Quick Reference", URL(string: "https://www.w3.org/WAI/WCAG22/quickref/")!)
        let notionAPI = artifact("Notion API Docs", URL(string: "https://developers.notion.com/")!)

        let fetchPage = command(
            "Fetch Web Page",
            curl,
            [
                .fixed(.string("-L")),
                .fixed(.string("--max-time")),
                .fixed(.string("20")),
                .fixed(.string("$URL"))
            ]
        )

        let searchLocalFiles = command(
            "Search Local Files",
            mdfind,
            [
                .fixed(.string("$QUERY"))
            ]
        )

        let folderInventory = command(
            "Folder Inventory",
            sh,
            [
                .fixed(.string("-c")),
                .fixed(.string(#"find "${TARGET_DIR:-$HOME/Documents}" -maxdepth 2 -type f | sed 's#^#- #' | head -200"#))
            ]
        )

        let focusMode = command(
            "Set Focus Mode",
            osascript,
            [
                .fixed(.string("-e")),
                .fixed(.string(#"tell application "System Events" to keystroke "f" using {control down, command down}"#))
            ]
        )

        let codex = artifact("Codex CLI", URL(fileURLWithPath: "/opt/homebrew/bin/codex"))

        let codexExec = command(
            "Codex Exec",
            codex,
            [
                .fixed(.string("exec")),
                .fixed(.string("--json")),
                .fixed(.string("--color")),
                .fixed(.string("never")),
                .fixed(.string("--skip-git-repo-check"))
            ]
        )

        let observerCommand = command(
            "Cron Observer",
            sh,
            [
                .fixed(.string("-c")),
                .fixed(.string(observerScript)),
                .fixed(.string("Scint-observer"))
            ]
        )

        let responses = command(
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

        let researchHarness = harness(
            "Research Briefing Agent",
            responses,
            .observe,
            [
                .argument(name: "audience", type: .string("operator"), required: false, default: nil),
                .argument(name: "output", type: .string("brief"), required: false, default: nil)
            ]
        )

        let evidenceHarness = harness(
            "Evidence Collector",
            fetchPage,
            .traverse,
            [
                .argument(name: "evidence", type: .string("source-first"), required: false, default: nil),
                .argument(name: "output", type: .string("citations"), required: false, default: nil)
            ]
        )

        let clientHarness = harness(
            "Client Operations Assistant",
            responses,
            .execute,
            [
                .argument(
                    name: "scope",
                    type: .string("client-work"),
                    required: false,
                    default: nil
                ),
                .argument(name: "output", type: .string("operator-ready draft"), required: false, default: nil)
            ]
        )

        let indexHarness = harness(
            "Local Context Indexer",
            folderInventory,
            .observe,
            [
                .argument(name: "source", type: .string("local-files"), required: false, default: nil),
                .argument(name: "output", type: .string("manifest"), required: false, default: nil)
            ]
        )

        let focusGuard = harness(
            "Focus Session Guard",
            focusMode,
            .execute,
            [
                .argument(name: "boundary", type: .string("local-device"), required: false, default: nil),
                .argument(name: "output", type: .string("focus-state"), required: false, default: nil)
            ]
        )

        let codexHarness = harness(
            "Codex CLI Agent",
            codexExec,
            .execute,
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

        let observerHarness = harness(
            "Observer",
            observerCommand,
            .observe,
            [
                .argument(
                    name: "operation",
                    type: .collection(["--operation": .sequence([.string("install"), .string("remove")])]),
                    required: false,
                    default: .collection(["--operation": .string("install")])
                ),
                .argument(name: "schedule", type: .collection(["--schedule": .string("")]), required: false, default: nil),
                .argument(name: "repeats", type: .collection(["--repeat": .bool(false)]), required: false, default: .collection(["--repeat": .bool(false)])),
                .target(
                    name: "action",
                    type: .sequence([.reference(Artifact.self), .reference(Command.self), .reference(Space.self), .reference(Workspace.self)]),
                    default: nil
                ),
                .target(
                    name: "target",
                    type: .anyReference,
                    default: nil
                )
            ]
        )

        return References(
            shell: sh,
            curl: curl,
            mdfind: mdfind,
            osascript: osascript,
            documents: documents,
            downloads: downloads,
            desktop: desktop,
            openAIDocs: openAIDocs,
            stripeDocs: stripeDocs,
            analyticsHelp: analyticsHelp,
            wcag: wcag,
            notionAPI: notionAPI,
            fetchPage: fetchPage,
            searchLocalFiles: searchLocalFiles,
            folderInventory: folderInventory,
            focusMode: focusMode,
            responses: responses,
            codex: codex,
            codexExec: codexExec,
            researchHarness: researchHarness,
            evidenceHarness: evidenceHarness,
            clientHarness: clientHarness,
            indexHarness: indexHarness,
            focusGuard: focusGuard,
            codexHarness: codexHarness,
            observerCommand: observerCommand,
            observerHarness: observerHarness
        )
    }
}
