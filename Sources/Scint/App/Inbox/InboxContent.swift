import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


extension Context.State {
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

extension Context {
    var updated: Date? {
        guard let ref = transcript, let script = Transcript.with(ref, { $0 }) else { return nil }
        return script.entries.last?.created
    }
}

struct InboxRow: View {
    var context: Context
    var model: any Model

    var harness: Reference? { Space.with(context.space, { $0.harness }) ?? nil }

    var message: String? {
        if let transcript = context.transcript {
            Transcript.with(transcript) { (transcript: Transcript) -> String? in
                guard case .collection(let fields)? = transcript.output("message")?.value, case .string(let text)? = fields["text"]
                        else { return nil }
                return text
            }
        }
        return nil
    }

    var body: some View {
        Button { model.select(context.space) } label: {
            ActivityRow(
                context.space.descriptor.name,
                icon: Iconography.icon(for: harness ?? context.space),
                time: context.updated?.formatted(.relative(presentation: .named))
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

struct InboxContent: Surface {
    var panel: any Panel
    var model: any Model

    var sections: [(state: Context.State, compositions: [Context])] {
        let compositions = Runtime.shared.resolve().sorted { ($0.updated ?? .distantPast) > ($1.updated ?? .distantPast) }
        return [Context.State.failed, .completed].compactMap { state -> (state: Context.State, compositions: [Context])? in
            let matching = compositions.filter { $0.state == state }
            return matching.isEmpty ? nil : (state, matching)
        }
    }

    var body: some View {
        ScrollView {
//            VStack(alignment: .leading, spacing: Style.Spacing.entry) {
//                ForEach(sections, id: \.state) { section in
//                    DisclosureSection(section.state.status.label, detail: "\(section.compositions.count)") {
//                        VStack(alignment: .leading, spacing: Style.Spacing.section) {
//                            ForEach(section.compositions, id: \.space) { composition in
//                                InboxRow(composition: composition, model: model)
//                            }
//                        }
//                    }
//                }
//            }
        }
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaBar(edge: .top) {
            InboxHeader(panel: panel, model: model)
        }
    }
}
