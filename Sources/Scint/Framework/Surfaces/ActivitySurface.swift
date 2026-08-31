import SwiftUI


struct ActivitySurface: Surface {
    var panel: any Panel
    var model: any Model

    func activity(in composition: Composition) -> Date {
        Transcript.with(composition.transcript) {
            $0.entries.last?.created ?? $0.started
        }.flatMap { $0 } ?? composition.transcript.descriptor.created
    }

    func branches(of composition: Composition) -> [Reference] {
        Transcript.with(composition.transcript, { $0.branches }) ?? []
    }

    @ViewBuilder private func card(_ composition: Composition, running: Bool) -> some View {
        let available = Set(composition.harnesses.compactMap { Harness.with($0, { $0.intent }) })
        let found = branches(of: composition)

        ActivityCard(
            model: model,
            space: composition.space,
            transcript: composition.transcript,
            running: running,
            expanded: isExpanded(composition.space),
            onToggle: { setExpanded(composition.space) }
        ) {
            ForEach(Harness.Intent.allCases, id: \.self) { intent in
                ActivityRow(
                    intent: intent,
                    transcript: found.first { $0.descriptor.name == intent.forms.label },
                    enabled: available.contains(intent),
                    model: model
                )
            }
        }
    }

    @ViewBuilder private func group(_ name: String, _ key: String, _ compositions: [Composition], running: Bool) -> some View {
        if !compositions.isEmpty {
            VStack(alignment: .leading, spacing: Style.Spacing.lg) {
                ActivityHeader(
                    name: name,
                    expanded: isExpanded(key),
                    onToggle: { setExpanded(key) }
                )
                if isExpanded(key) {
                    ForEach(compositions, id: \.space) { card($0, running: running) }
                }
            }
        }
    }

    var body: some View {
        let compositions = Runtime.shared.context().sorted { activity(in: $0) > activity(in: $1) }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Style.Spacing.xxl) {
                group("Working", "working", compositions.filter { $0.state != .inactive }, running: true)
                group("Recent", "recent", compositions.filter { $0.state == .inactive && !branches(of: $0).isEmpty }, running: false)
            }
            .padding(.horizontal, Style.Spacing.lg)
            .padding(.vertical, Style.Spacing.xl)
        }
    }
}

