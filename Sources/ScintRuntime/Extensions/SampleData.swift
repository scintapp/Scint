import Foundation


enum SampleData {
    static let interfaces = SampleInterfaces.load()

    static func load(_ workspace: Reference, for key: ModelKey) async {
        switch key {
            case .editor: await editor(workspace)
            case .studio: await studio(workspace)
        }
    }

    static func assistant(_ workspace: Reference) async { }
    static func builder(_ workspace: Reference) async { }
    static func editor(_ workspace: Reference) async { }
    static func panels(_ workspace: Reference) async { }
    static func studio(_ workspace: Reference) async {
        let hasWorkspaces = Workspace.with(workspace, { !$0.spaces.isEmpty }) ?? false
        let codexHarness = interfaces.codexHarness
        let assistantHarness = interfaces.assistantHarness
        let mistralMessages = interfaces.mistralMessages
        let researchCommands = [
            interfaces.searchTextFiles,
            interfaces.inspectFileMetadata,
            interfaces.fetchURLHeaders
        ]

        if hasWorkspaces {
            let researchDesk = Runtime.shared.context(from: workspace).first {
                $0.type == Space.self && $0.descriptor.name == "Research Desk"
            }
            if let researchDesk {
                Space.update(researchDesk) { space in
                    for command in researchCommands { space.add(command) }
                }
            }
            return
        }

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

        let contentStudio = Space.new("Content Studio", owner: workspace)
        let researchDesk = Space.new("Research Desk", owner: contentStudio)
        let contentProduction = Space.new("Content Production", owner: contentStudio)
        let editorialCalendar = Space.new("Editorial Calendar", owner: contentProduction)

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
    }
}
