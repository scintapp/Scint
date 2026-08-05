import Foundation


public enum SampleData {
    public static func load(_ workspace: Reference) async {
        let interfaces = SampleInterfaces.load()
        let hasWorkspaces = Workspace.with(workspace, { !$0.spaces.isEmpty }) ?? false
        guard !hasWorkspaces else { return }

        let documents = interfaces.documents
        let downloads = interfaces.downloads
        let desktop = interfaces.desktop
        let openAIDocs = interfaces.openAIDocs
        let stripeDocs = interfaces.stripeDocs
        let analyticsHelp = interfaces.analyticsHelp
        let wcag = interfaces.wcag
        let notionAPI = interfaces.notionAPI
        let webFetch = interfaces.fetchPage
        let localSearch = interfaces.searchLocalFiles
        let folderInventory = interfaces.folderInventory
        let responses = interfaces.responses
        let researchHarness = interfaces.researchHarness
        let evidenceHarness = interfaces.evidenceHarness
        let clientHarness = interfaces.clientHarness
        let indexHarness = interfaces.indexHarness
        let codex = interfaces.codex
        let codexExec = interfaces.codexExec
        let codexHarness = interfaces.codexHarness

        Workspace.update(workspace, { ws in
            let components = [
                documents,
                downloads,
                desktop,
                openAIDocs,
                stripeDocs,
                analyticsHelp,
                wcag,
                notionAPI,
                webFetch,
                localSearch,
                folderInventory,
                responses,
                codex,
                codexExec,
                researchHarness,
                evidenceHarness,
                clientHarness,
                indexHarness,
                interfaces.focusGuard,
                codexHarness
            ]
            for component in components { ws.add(component) }
            ws.name = "Scint"
        })

        func write(_ ref: Reference, title: String, body: [String], components: [Reference], tasks: [(String, Bool)]) {
            Sheet.update(ref) { sheet in
                sheet.insert(.text(.init(), "# \(title)"), at: nil)
                for paragraph in body {
                    sheet.insert(.text(.init(), paragraph), at: nil)
                }
                for component in components {
                    switch component.type {
                        case is Artifact.Type: sheet.insert(.artifact(component), at: nil)
                        case is Command.Type: sheet.insert(.command(component), at: nil)
                        case is Sheet.Type: sheet.insert(.sheet(component), at: nil)
                        default: break
                    }
                }
                for task in tasks {
                    sheet.insert(.task(.init(), task.0, task.1), at: nil)
                }
            }
        }

        @discardableResult
        func sheet(_ name: String, owner: Reference, title: String, body: [String], components: [Reference], tasks: [(String, Bool)]) -> Reference {
            let ref = Sheet.new(owner, name: name)
            write(ref, title: title, body: body, components: components, tasks: tasks)
            return ref
        }

        func configure(_ spaceRef: Reference, description: String, sheets: [Reference], components: [Reference], harness: Reference? = nil) {
            Space.update(spaceRef) { space in
                space.description = description
                if let harness { space.harness = harness }
                for ref in sheets + components { space.add(ref) }
            }
        }

        let independentStudio = Space.new("Independent Studio", owner: workspace)
        let contentPractice = Space.new("Content Practice", owner: workspace)
        let customerLearningLab = Space.new("Customer Learning Lab", owner: workspace)
        let operationsUtility = Space.new("Operations Utility", owner: workspace)

        let clientIntake = Space.new("Client Intake", owner: independentStudio)
        let proposalAssembly = Space.new("Proposal Assembly", owner: independentStudio)
        let retainerOperations = Space.new("Retainer Operations", owner: independentStudio)
        let discoveryCallPrep = Space.new("Discovery Call Prep", owner: clientIntake)

        let researchDesk = Space.new("Research Desk", owner: contentPractice)
        let editorialCalendar = Space.new("Editorial Calendar", owner: contentPractice)
        let repurposingWorkflow = Space.new("Repurposing Workflow", owner: contentPractice)
        let sourceTriage = Space.new("Source Triage", owner: researchDesk)

        let curriculumDesign = Space.new("Curriculum Design", owner: customerLearningLab)
        let feedbackSynthesis = Space.new("Feedback Synthesis", owner: customerLearningLab)
        let supportPlaybooks = Space.new("Support Playbooks", owner: customerLearningLab)
        let transcriptReview = Space.new("Transcript Review", owner: feedbackSynthesis)

        let financeReview = Space.new("Finance Review", owner: operationsUtility)
        let vendorFollowUp = Space.new("Vendor Follow-Up", owner: operationsUtility)
        let weeklyCommandCenter = Space.new("Weekly Command Center", owner: operationsUtility)

        let studioMap = sheet(
            "Studio Operating Map",
            owner: independentStudio,
            title: "Studio Operating Map",
            body: [
                "This space coordinates a solo studio where discovery, proposals, delivery notes, and follow-up drafts can be delegated without losing operator judgment.",
                "Agents may prepare briefs, summarize evidence, and draft next palette. They must leave pricing, scope commitments, and relationship-sensitive wording for human approval."
            ],
            components: [documents, localSearch, clientHarness],
            tasks: [
                ("Confirm which client folders are allowed as context before running local search.", false),
                ("Mark any assumptions that would affect scope, schedule, or price.", false),
                ("Keep final outreach drafts in a review state until the operator accepts them.", true)
            ]
        )
        let studioBoundary = sheet(
            "Client Work Boundary",
            owner: independentStudio,
            title: "Client Work Boundary",
            body: [
                "Use this sheet as the guardrail for client-facing runs. The agent can organize material and suggest language, but it cannot invent commitments or imply availability.",
                "When evidence is missing, the correct behavior is to ask for the source, not to fill the gap with plausible business language."
            ],
            components: [openAIDocs, folderInventory, indexHarness],
            tasks: [
                ("Flag missing source material as a blocker instead of drafting around it.", false),
                ("Separate facts from recommended positioning in every generated brief.", false),
                ("Capture reusable phrasing in the client library after approval.", false)
            ]
        )
        configure(
            independentStudio,
            description: "Client-facing process sheets for an independent consulting studio.",
            sheets: [studioMap, studioBoundary],
            components: [documents, clientHarness, indexHarness],
            harness: clientHarness
        )

        let intakeInterview = sheet(
            "Intake Interview Script",
            owner: clientIntake,
            title: "Intake Interview Script",
            body: [
                "Prepare a structured discovery call from the prospect's notes, website, and any forwarded email context. The agent should identify the business objective before summarizing requested work.",
                "The output should read like a call plan, not a questionnaire dump. Each question needs a reason so the operator can decide what to ask live."
            ],
            components: [webFetch, localSearch],
            tasks: [
                ("Collect the prospect URL and latest email thread before running the brief.", false),
                ("Group questions by business goal, constraints, existing assets, and decision process.", false),
                ("Add a final section for risks that should not be answered during the call.", false)
            ]
        )
        let sourceRequest = sheet(
            "Source Material Request",
            owner: clientIntake,
            title: "Source Material Request",
            body: [
                "Draft a short request for the materials needed to evaluate the project. The agent should explain why each source is useful without making the client feel like homework was assigned.",
                "Prefer specific asks: current dashboard export, last campaign brief, existing brand guide, or three examples of work they want to emulate."
            ],
            components: [documents, downloads],
            tasks: [
                ("Ask for examples, constraints, owners, and timelines in separate bullets.", false),
                ("Offer a fallback when a requested artifact does not exist.", false),
                ("Keep tone practical and low-friction.", true)
            ]
        )
        configure(
            clientIntake,
            description: "Turns scattered prospect context into call plans and clear source requests.",
            sheets: [intakeInterview, sourceRequest],
            components: [webFetch, localSearch, clientHarness],
            harness: clientHarness
        )

        let callBrief = sheet(
            "Call Brief Assembly",
            owner: discoveryCallPrep,
            title: "Call Brief Assembly",
            body: [
                "Assemble a one-page brief before a discovery call. The agent should summarize what is known, list what remains uncertain, and propose the order of conversation.",
                "The brief should reduce live cognitive load. It should not try to close the sale before the operator understands the problem."
            ],
            components: [webFetch, folderInventory],
            tasks: [
                ("Include the client's current public positioning in three sentences or fewer.", false),
                ("List no more than five high-leverage questions.", false),
                ("End with a decision note: qualify, nurture, or decline.", false)
            ]
        )
        let followUpPacket = sheet(
            "Follow-Up Packet Instructions",
            owner: discoveryCallPrep,
            title: "Follow-Up Packet Instructions",
            body: [
                "After the call, produce a follow-up packet that separates recap, open questions, and proposed next step. The agent should use the operator's notes as source of truth.",
                "If the notes are thin, the packet must say so. The goal is a reliable handoff, not a polished hallucination."
            ],
            components: [documents, responses],
            tasks: [
                ("Quote operator notes when summarizing the client's stated priority.", false),
                ("Add a checklist of missing inputs before proposal drafting starts.", false),
                ("Keep the proposed next step reversible until confirmed.", false)
            ]
        )
        configure(
            discoveryCallPrep,
            description: "Pre-call and post-call runbooks for turning discovery into usable context.",
            sheets: [callBrief, followUpPacket],
            components: [documents, webFetch, responses],
            harness: researchHarness
        )

        let proposalDraft = sheet(
            "Proposal Draft Spec",
            owner: proposalAssembly,
            title: "Proposal Draft Spec",
            body: [
                "Generate the first proposal draft from approved discovery notes. The agent should convert client language into a clear outcome, then outline activities, exclusions, and collaboration needs.",
                "The agent may suggest pricing models but must not choose final rates. Any uncertainty about effort should be returned as a decision for the operator."
            ],
            components: [documents, responses],
            tasks: [
                ("Use client-stated outcomes before studio capabilities.", false),
                ("List exclusions beside the relevant deliverable.", false),
                ("Place all pricing assumptions in a separate review block.", false)
            ]
        )
        let pricingReview = sheet(
            "Pricing Assumption Review",
            owner: proposalAssembly,
            title: "Pricing Assumption Review",
            body: [
                "Review proposal assumptions before price is finalized. The agent should check for hidden project management, content migration, stakeholder review, or data cleanup work.",
                "Output should be a concise risk register that helps the operator adjust scope without turning the proposal into a defensive document."
            ],
            components: [localSearch, stripeDocs],
            tasks: [
                ("Identify work implied by client language but absent from deliverables.", false),
                ("Call out payment schedule risks separately from delivery risks.", false),
                ("Suggest one simpler scope option if risk is high.", false)
            ]
        )
        configure(
            proposalAssembly,
            description: "Proposal sheets that turn discovery into scoped, reviewable client offers.",
            sheets: [proposalDraft, pricingReview],
            components: [responses, stripeDocs, clientHarness],
            harness: clientHarness
        )

        let weeklyClientReview = sheet(
            "Weekly Client Review",
            owner: retainerOperations,
            title: "Weekly Client Review",
            body: [
                "Create a weekly client-facing status note from completed work, blockers, and pending decisions. The agent should keep the note short enough to be read in one pass.",
                "The operator owns relationship tone. The agent should surface sensitive items, then draft neutral language for approval."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Group updates into shipped, in progress, blocked, and needs decision.", false),
                ("Add evidence links only when they help the client act.", false),
                ("Never bury a blocker inside a progress paragraph.", true)
            ]
        )
        let scopeDrift = sheet(
            "Scope Drift Watch",
            owner: retainerOperations,
            title: "Scope Drift Watch",
            body: [
                "Scan notes for requests that may be outside the current agreement. The agent should classify the request, quote the evidence, and suggest whether to absorb, defer, or rescope.",
                "This sheet is protective, not adversarial. The goal is to keep promises explicit before extra work becomes invisible."
            ],
            components: [localSearch, documents],
            tasks: [
                ("Quote the exact request that triggered the drift check.", false),
                ("Compare the request to the active scope summary.", false),
                ("Draft a client-safe clarification if rescoping is recommended.", false)
            ]
        )
        configure(
            retainerOperations,
            description: "Ongoing client operations with explicit status, scope, and decision tracking.",
            sheets: [weeklyClientReview, scopeDrift],
            components: [documents, localSearch, clientHarness],
            harness: clientHarness
        )

        let editorialCharter = sheet(
            "Editorial System Charter",
            owner: contentPractice,
            title: "Editorial System Charter",
            body: [
                "This space runs a professional publishing practice where research notes become briefs, drafts, newsletters, and reusable clips.",
                "Agents may organize sources, extract claims, and draft options. They must preserve attribution and make uncertainty visible."
            ],
            components: [documents, webFetch, researchHarness],
            tasks: [
                ("Require source links for any claim that sounds empirical.", false),
                ("Keep personal opinion separate from sourced findings.", false),
                ("Store reusable examples after the operator approves them.", false)
            ]
        )
        let voiceRules = sheet(
            "Voice and Evidence Rules",
            owner: contentPractice,
            title: "Voice and Evidence Rules",
            body: [
                "Define the house style for agent-assisted writing. The agent should be specific, grounded, and willing to leave rough edges where the operator needs to decide.",
                "Avoid generic thought-leadership phrasing. The strongest output should feel like a knowledgeable person organizing a real argument."
            ],
            components: [wcag, openAIDocs],
            tasks: [
                ("Prefer concrete examples over category labels.", false),
                ("Preserve named sources and dates in research summaries.", false),
                ("Flag unsupported claims instead of smoothing them over.", true)
            ]
        )
        configure(
            contentPractice,
            description: "Research, drafting, and publishing process sheets for a knowledge business.",
            sheets: [editorialCharter, voiceRules],
            components: [researchHarness, evidenceHarness, webFetch],
            harness: researchHarness
        )

        let researchBrief = sheet(
            "Research Brief Template",
            owner: researchDesk,
            title: "Research Brief Template",
            body: [
                "Turn a topic prompt into a research brief with a working question, audience context, source plan, and expected use of the finished work.",
                "The agent should make the research path inspectable. A good brief tells the operator what the agent will look for and what it will ignore."
            ],
            components: [webFetch, openAIDocs],
            tasks: [
                ("State the working question before collecting sources.", false),
                ("Limit initial source categories to primary, expert, and counterexample.", false),
                ("Name the intended output: essay, client memo, talk, or product note.", false)
            ]
        )
        let reliabilityNotes = sheet(
            "Source Reliability Notes",
            owner: researchDesk,
            title: "Source Reliability Notes",
            body: [
                "Evaluate source quality before the agent quotes or summarizes it. The agent should distinguish primary documentation, expert commentary, marketing claims, and anecdotal evidence.",
                "The output is a source ledger. It does not need to be elegant, but it needs to be traceable."
            ],
            components: [webFetch, wcag],
            tasks: [
                ("Record author, date, publisher, and reason for inclusion.", false),
                ("Mark sources that are useful for framing but weak as evidence.", false),
                ("Keep rejected sources with a short reason.", false)
            ]
        )
        configure(
            researchDesk,
            description: "Reusable research methods for source-led writing and strategic analysis.",
            sheets: [researchBrief, reliabilityNotes],
            components: [webFetch, evidenceHarness],
            harness: evidenceHarness
        )

        let sourceQueue = sheet(
            "Source Queue Instructions",
            owner: sourceTriage,
            title: "Source Queue Instructions",
            body: [
                "Build a queue of candidate sources before synthesis starts. The agent should collect enough context to decide whether a source deserves a full read.",
                "Keep the queue narrow. The point is to protect attention, not to hoard links."
            ],
            components: [webFetch, downloads],
            tasks: [
                ("Tag each source as primary, analysis, example, or noise.", false),
                ("Extract one possible use for each accepted source.", false),
                ("Stop when the queue contains enough tension to write from.", false)
            ]
        )
        let claimExtraction = sheet(
            "Claim Extraction Pass",
            owner: sourceTriage,
            title: "Claim Extraction Pass",
            body: [
                "Extract claims from accepted sources into a structured list. The agent should include the claim, evidence, source link, and confidence note.",
                "Claims are not draft paragraphs. They are raw material for argument design."
            ],
            components: [webFetch, responses],
            tasks: [
                ("Separate descriptive claims from prescriptive claims.", false),
                ("Quote exact source language when a claim may be contested.", false),
                ("Add a confidence label for every claim.", false)
            ]
        )
        configure(
            sourceTriage,
            description: "Third-level source handling before research becomes synthesis.",
            sheets: [sourceQueue, claimExtraction],
            components: [webFetch, evidenceHarness],
            harness: evidenceHarness
        )

        let publishingCadence = sheet(
            "Publishing Cadence",
            owner: editorialCalendar,
            title: "Publishing Cadence",
            body: [
                "Maintain an editorial calendar that reflects actual production capacity. The agent should suggest sequencing based on source readiness, business relevance, and required review.",
                "A calendar item is not ready just because it has a title. It needs a usable angle and source path."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Mark each planned piece as idea, researched, drafted, or scheduled.", false),
                ("Prefer fewer stronger pieces over a crowded calendar.", true),
                ("Keep business launch dates visible beside editorial dates.", false)
            ]
        )
        let draftReadiness = sheet(
            "Draft Readiness Checklist",
            owner: editorialCalendar,
            title: "Draft Readiness Checklist",
            body: [
                "Before a draft run starts, check whether the piece has a clear reader, point of view, evidence base, and desired action.",
                "The agent should return a readiness verdict. If not ready, it should recommend the smallest next action."
            ],
            components: [researchHarness, responses],
            tasks: [
                ("Confirm reader, promise, evidence, and CTA.", false),
                ("List the missing item that most blocks drafting.", false),
                ("Do not produce a full draft from an unresolved angle.", false)
            ]
        )
        configure(
            editorialCalendar,
            description: "Planning sheets that keep publishing tied to research readiness and business timing.",
            sheets: [publishingCadence, draftReadiness],
            components: [documents, researchHarness],
            harness: researchHarness
        )

        let longformToShortform = sheet(
            "Longform to Shortform Spec",
            owner: repurposingWorkflow,
            title: "Longform to Shortform Spec",
            body: [
                "Convert an approved longform piece into shortform assets without stripping out the underlying argument. The agent should preserve the core claim and vary the entry point.",
                "Do not turn every paragraph into a post. Choose only the segments that can stand alone."
            ],
            components: [documents, responses],
            tasks: [
                ("Extract three strong claims and one practical example.", false),
                ("Draft variants for LinkedIn, newsletter teaser, and short note.", false),
                ("Keep a link back to the canonical longform piece.", false)
            ]
        )
        let newsletterAssembly = sheet(
            "Newsletter Assembly Notes",
            owner: repurposingWorkflow,
            title: "Newsletter Assembly Notes",
            body: [
                "Assemble a newsletter from approved research, client-safe examples, and current business context. The agent should keep the voice direct and useful.",
                "The newsletter can reuse material, but it should still have a reason to exist this week."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Open with the practical reason the topic matters now.", false),
                ("Include one useful link or artifact for the reader.", false),
                ("End with a clear next action, not a vague signoff.", false)
            ]
        )
        configure(
            repurposingWorkflow,
            description: "Turns approved longform thinking into smaller, source-aware publishing assets.",
            sheets: [longformToShortform, newsletterAssembly],
            components: [documents, responses, researchHarness],
            harness: researchHarness
        )

        let learningMap = sheet(
            "Learning Program Map",
            owner: customerLearningLab,
            title: "Learning Program Map",
            body: [
                "This space helps a founder or educator turn expertise into lessons, support scripts, and feedback loops that can be improved by agents.",
                "Agents may synthesize learner signals and draft lesson components, but the operator decides what good judgment looks like in the domain."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Define what the learner should be able to do after each module.", false),
                ("Keep support language aligned with lesson language.", false),
                ("Review generated exercises for domain accuracy before publishing.", false)
            ]
        )
        let learnerSignal = sheet(
            "Learner Signal Policy",
            owner: customerLearningLab,
            title: "Learner Signal Policy",
            body: [
                "Set rules for how agents interpret feedback, support messages, survey responses, and completion notes. Treat learner friction as evidence, not irritation.",
                "The agent should preserve the difference between confusion, disagreement, missing context, and tooling problems."
            ],
            components: [documents, analyticsHelp],
            tasks: [
                ("Classify feedback by learning gap, product gap, motivation, or environment.", false),
                ("Quote representative learner language before summarizing patterns.", false),
                ("Avoid treating completion rate as the only success signal.", true)
            ]
        )
        configure(
            customerLearningLab,
            description: "Agent process sheets for courses, onboarding, feedback, and support quality.",
            sheets: [learningMap, learnerSignal],
            components: [documents, analyticsHelp, researchHarness],
            harness: researchHarness
        )

        let lessonBrief = sheet(
            "Lesson Design Brief",
            owner: curriculumDesign,
            title: "Lesson Design Brief",
            body: [
                "Draft a lesson brief from a target skill, learner state, and business promise. The agent should propose the smallest useful lesson, not a complete curriculum expansion.",
                "Every lesson should include a behavior, context, example, practice task, and review cue."
            ],
            components: [documents, responses],
            tasks: [
                ("State the learner's current obstacle in plain language.", false),
                ("Include one worked example and one practice prompt.", false),
                ("List what the lesson intentionally does not cover.", false)
            ]
        )
        let exerciseGenerator = sheet(
            "Practice Exercise Generator",
            owner: curriculumDesign,
            title: "Practice Exercise Generator",
            body: [
                "Generate practice exercises that reveal whether the learner can use the concept, not whether they can repeat the explanation.",
                "The agent should produce realistic constraints and a rubric that the operator can inspect quickly."
            ],
            components: [responses, wcag],
            tasks: [
                ("Create one easy, one normal, and one messy scenario.", false),
                ("Attach a simple rubric with observable criteria.", false),
                ("Avoid examples that require unavailable background knowledge.", false)
            ]
        )
        configure(
            curriculumDesign,
            description: "Lesson and practice design sheets for expert-led education products.",
            sheets: [lessonBrief, exerciseGenerator],
            components: [responses, wcag],
            harness: researchHarness
        )

        let feedbackProtocol = sheet(
            "Feedback Review Protocol",
            owner: feedbackSynthesis,
            title: "Feedback Review Protocol",
            body: [
                "Review a batch of learner feedback and turn it into patterns, open questions, and recommended changes. The agent should not over-index on the loudest message.",
                "The best output helps the operator decide what to change, what to watch, and what to leave alone."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Group feedback by repeated learner friction, not sentiment alone.", false),
                ("List exact quotes for the top three patterns.", false),
                ("Recommend one change that can be tested next cycle.", false)
            ]
        )
        let patternSummary = sheet(
            "Pattern Summary Instructions",
            owner: feedbackSynthesis,
            title: "Pattern Summary Instructions",
            body: [
                "Summarize patterns from feedback without erasing nuance. The agent should distinguish signal volume from strategic importance.",
                "When a pattern is ambiguous, it should produce competing interpretations rather than forcing a single answer."
            ],
            components: [analyticsHelp, responses],
            tasks: [
                ("Report pattern, evidence, likely cause, and proposed response.", false),
                ("Mark thin evidence as thin evidence.", true),
                ("Keep operator decisions separate from agent observations.", false)
            ]
        )
        configure(
            feedbackSynthesis,
            description: "Turns learner feedback and support signals into decisions for the next iteration.",
            sheets: [feedbackProtocol, patternSummary],
            components: [analyticsHelp, responses, researchHarness],
            harness: researchHarness
        )

        let codingGuide = sheet(
            "Interview Coding Guide",
            owner: transcriptReview,
            title: "Interview Coding Guide",
            body: [
                "Code learner interview transcripts for moments of confusion, confidence, workaround, and desired outcome. The agent should preserve quote context.",
                "Tags are useful only if they help redesign lessons or support workflows."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Tag each quote with learner state and lesson area.", false),
                ("Extract one sentence before and after important quotes.", false),
                ("Do not infer motivation when the learner only described behavior.", false)
            ]
        )
        let quoteBank = sheet(
            "Quote Bank Rules",
            owner: transcriptReview,
            title: "Quote Bank Rules",
            body: [
                "Build a quote bank from interview notes that can support product, curriculum, and marketing decisions. The agent should keep quote provenance intact.",
                "Sensitive or personally identifying material should be redacted before a quote moves into reusable context."
            ],
            components: [documents, wcag],
            tasks: [
                ("Record speaker, date, context, and permission status.", false),
                ("Redact identifying details before reuse.", false),
                ("Keep marketing-worthy quotes separate from design evidence.", false)
            ]
        )
        configure(
            transcriptReview,
            description: "Third-level transcript processing for learner interviews and quote reuse.",
            sheets: [codingGuide, quoteBank],
            components: [documents, researchHarness],
            harness: researchHarness
        )

        let escalationClassifier = sheet(
            "Escalation Classifier",
            owner: supportPlaybooks,
            title: "Escalation Classifier",
            body: [
                "Classify incoming support notes so the agent can route common issues and hold sensitive items for the operator.",
                "Escalation should be based on risk, ambiguity, and relationship impact, not merely message length."
            ],
            components: [documents, responses],
            tasks: [
                ("Route billing, safety, legal, and angry customer notes to human review.", false),
                ("Draft calm first responses for routine access issues.", false),
                ("Include missing context needed to resolve the case.", false)
            ]
        )
        let articleRefresh = sheet(
            "Help Article Refresh",
            owner: supportPlaybooks,
            title: "Help Article Refresh",
            body: [
                "Update help content from repeated support questions. The agent should identify the precise misunderstanding and propose clearer wording.",
                "The refresh should make the next support interaction less likely, not just answer the last ticket."
            ],
            components: [documents, wcag],
            tasks: [
                ("Match each proposed edit to a real support pattern.", false),
                ("Use headings that reflect user intent.", false),
                ("Check accessibility and plain-language issues before publishing.", false)
            ]
        )
        configure(
            supportPlaybooks,
            description: "Support operations that convert recurring questions into better routing and documentation.",
            sheets: [escalationClassifier, articleRefresh],
            components: [documents, wcag, responses],
            harness: clientHarness
        )

        let weeklyReview = sheet(
            "Solo Operator Weekly Review",
            owner: operationsUtility,
            title: "Solo Operator Weekly Review",
            body: [
                "This space collects business operations for a solo founder or freelancer: finance, vendors, priorities, and weekly command decisions.",
                "Agents can prepare the review, surface anomalies, and draft follow-ups. The operator decides what matters."
            ],
            components: [documents, folderInventory, indexHarness],
            tasks: [
                ("Summarize commitments due this week before suggesting new work.", false),
                ("Panel cash, client, and delivery risks separately.", false),
                ("End with no more than three operator decisions.", false)
            ]
        )
        let decisionLog = sheet(
            "Decision Log Policy",
            owner: operationsUtility,
            title: "Decision Log Policy",
            body: [
                "Record decisions in a form that future agents can use. Each decision should include context, options considered, chosen path, and review trigger.",
                "A decision log is not a diary. It is executable memory for future runs."
            ],
            components: [documents, notionAPI],
            tasks: [
                ("Capture the reason for the decision, not just the outcome.", false),
                ("Add the review date or condition that would reopen the decision.", false),
                ("Link decisions to affected clients, projects, or systems.", false)
            ]
        )
        configure(
            operationsUtility,
            description: "A practical operating layer for finance, vendor, and weekly decision processes.",
            sheets: [weeklyReview, decisionLog],
            components: [documents, folderInventory, indexHarness],
            harness: indexHarness
        )

        let cashNarrative = sheet(
            "Cash Position Narrative",
            owner: financeReview,
            title: "Cash Position Narrative",
            body: [
                "Convert finance inputs into a plain-language cash position narrative. The agent should explain what changed, what is expected, and what decision is needed.",
                "This is not bookkeeping. It is an operator-facing view that makes the next business move clearer."
            ],
            components: [documents, stripeDocs],
            tasks: [
                ("Separate current balance, expected inflows, expected outflows, and risk.", false),
                ("Flag invoices that are material to next month's runway.", false),
                ("Do not recommend spending changes without stating the assumption.", false)
            ]
        )
        let expenseSweep = sheet(
            "Expense Anomaly Sweep",
            owner: financeReview,
            title: "Expense Anomaly Sweep",
            body: [
                "Scan exported expenses for unfamiliar vendors, duplicate charges, or subscriptions that no longer match active work.",
                "The agent should return a review list with evidence and a proposed action, not a scary dashboard."
            ],
            components: [downloads, localSearch],
            tasks: [
                ("Group anomalies by duplicate, unexpected, expired, or needs context.", false),
                ("Include exact transaction evidence for each flagged item.", false),
                ("Draft cancellation or clarification notes only after review.", false)
            ]
        )
        let invoiceMatching = sheet(
            "Invoice Matching Run",
            owner: financeReview,
            title: "Invoice Matching Run",
            body: [
                "Match invoices against payment records, client notes, and expected billing dates. The agent should identify confidence level for each match.",
                "Anything uncertain should stay in review. Do not mark a payment resolved because names look similar."
            ],
            components: [downloads, stripeDocs, localSearch],
            tasks: [
                ("Match by client, amount, date range, and invoice identifier.", false),
                ("Mark partial matches for operator review.", false),
                ("Prepare a short unresolved invoice list.", false)
            ]
        )
        let paymentFollowUp = sheet(
            "Payment Follow-Up Draft",
            owner: financeReview,
            title: "Payment Follow-Up Draft",
            body: [
                "Draft payment follow-up language after invoice reconciliation. The agent should keep the tone firm, respectful, and specific.",
                "The draft must reference the invoice and prior agreement, then offer an easy path to resolve confusion."
            ],
            components: [stripeDocs, responses],
            tasks: [
                ("Include invoice number, amount, due date, and payment link placeholder.", false),
                ("Use a neutral tone unless the operator selects escalation.", false),
                ("Leave relationship-sensitive wording for review.", false)
            ]
        )
        configure(
            financeReview,
            description: "Finance review sheets that produce readable operator decisions from source material.",
            sheets: [cashNarrative, expenseSweep, invoiceMatching, paymentFollowUp],
            components: [documents, downloads, stripeDocs, responses, indexHarness],
            harness: indexHarness
        )

        let vendorStatus = sheet(
            "Vendor Status Brief",
            owner: vendorFollowUp,
            title: "Vendor Status Brief",
            body: [
                "Summarize vendor status before renewal, escalation, or cleanup. The agent should gather contract notes, last contact, current value, and unresolved issues.",
                "The brief should support a decision: keep, renegotiate, replace, or cancel."
            ],
            components: [documents, localSearch],
            tasks: [
                ("Find the latest agreement or invoice before writing the brief.", false),
                ("List open issues separately from general satisfaction.", false),
                ("Recommend a decision category with supporting evidence.", false)
            ]
        )
        let renewalRisk = sheet(
            "Renewal Risk Scan",
            owner: vendorFollowUp,
            title: "Renewal Risk Scan",
            body: [
                "Check upcoming renewals for price changes, unused seats, missing owners, or dependencies that make cancellation risky.",
                "The agent should present options in business terms so the operator can act without rereading every contract."
            ],
            components: [folderInventory, documents],
            tasks: [
                ("Flag renewals inside the next 45 days.", false),
                ("Identify who uses the vendor and what breaks if it is canceled.", false),
                ("Draft a negotiation or cancellation note when appropriate.", false)
            ]
        )
        configure(
            vendorFollowUp,
            description: "Vendor management sheets for renewals, contract context, and practical follow-up.",
            sheets: [vendorStatus, renewalRisk],
            components: [documents, folderInventory, clientHarness],
            harness: clientHarness
        )

        let mondayLaunch = sheet(
            "Monday Launch Plan",
            owner: weeklyCommandCenter,
            title: "Monday Launch Plan",
            body: [
                "Prepare the week by reviewing obligations, risks, and decision points. The agent should turn scattered notes into a short operating plan.",
                "The plan should not maximize tasks. It should protect the week from avoidable surprises."
            ],
            components: [documents, folderInventory],
            tasks: [
                ("List immovable commitments before suggested work.", false),
                ("Choose no more than three priorities.", false),
                ("Name one thing to intentionally defer.", false)
            ]
        )
        let fridayCloseout = sheet(
            "Friday Closeout Review",
            owner: weeklyCommandCenter,
            title: "Friday Closeout Review",
            body: [
                "Close the week by capturing shipped work, unfinished obligations, lessons, and follow-ups. The agent should prepare next week's context while events are fresh.",
                "The output should be useful to Monday's agent run and readable by the operator in under five minutes."
            ],
            components: [documents, responses],
            tasks: [
                ("Summarize outcomes before listing activity.", false),
                ("Carry forward only commitments that still matter.", false),
                ("Add decisions and unresolved questions to the log.", false)
            ]
        )
        configure(
            weeklyCommandCenter,
            description: "Weekly operating rhythms that keep agent runs aligned with human priorities.",
            sheets: [mondayLaunch, fridayCloseout],
            components: [documents, responses, indexHarness],
            harness: indexHarness
        )
    }
}
