import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


extension Composition.State {
    var status: (label: String, tint: Style.Tint) {
        switch self {
            case .active: ("Active", Style.Tint.accent)
            case .working: ("Working", Style.Tint.accent)
            case .completed: ("Complete", Style.Tint.space)
            case .failed: ("Needs attention", Style.Tint.alert)
            case .inactive: ("Ready", Style.Tint.neutral)
        }
    }
}

extension Composition {
    var updated: Date? { Transcript.with(transcript, { $0.entries.last?.created }) ?? nil }
}

struct InboxRow: View {
    var composition: Composition
    var model: any Model

    var harness: Reference? { Space.with(composition.space, { $0.harness }) ?? nil }

    var message: String? {
        Transcript.with(composition.transcript) { (transcript: Transcript) -> String? in
            guard case .collection(let fields)? = transcript.output("message")?.value, case .string(let text)? = fields["text"]
            else { return nil }
            return text
        } ?? nil
    }

    var body: some View {
        Button { model.select(composition.space) } label: {
            ActivityRow(
                composition.space.descriptor.name,
                icon: Iconography.model(for: harness ?? composition.space),
                time: composition.updated?.formatted(.relative(presentation: .named))
            ) {
                if let message {
                    Text((try? AttributedString(markdown: message, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message))
                        .lineLimit(2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Inbox: Surface {
    var panel: any Panel
    var model: any Model

    var sections: [(state: Composition.State, compositions: [Composition])] {
        let compositions = Runtime.shared.resolve().sorted { ($0.updated ?? .distantPast) > ($1.updated ?? .distantPast) }
        return [Composition.State.failed, .completed].compactMap { state -> (state: Composition.State, compositions: [Composition])? in
            let matching = compositions.filter { $0.state == state }
            return matching.isEmpty ? nil : (state, matching)
        }
    }

    var body: some View {
        let sections = sections

        if sections.isEmpty { NoReference(ref: model.session.inbox, title: "Nothing Here") }
        else {
            ScrollView {
                VStack(alignment: .leading, spacing: Style.Spacing.page) {
                    PageHeader("Inbox")

                    ForEach(sections, id: \.state) { section in
                        DisclosureSection(section.state.status.label, detail: "\(section.compositions.count)") {
                            VStack(alignment: .leading, spacing: Style.Spacing.section) {
                                ForEach(section.compositions, id: \.space) { composition in
                                    InboxRow(composition: composition, model: model)
                                }
                            }
                        }
                    }
                }
                .font(Typography.body)
                .frame(maxWidth: Typography.Prose.readableWidth, alignment: .leading)
                .padding(Style.Spacing.page)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
