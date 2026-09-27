import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskSetupSummary: View {
    let rows: [ItemParams]
    let expanded: Bool
    let onToggle: () -> Void

    var summary: String { rows.map { "\($0.description) \($0.name.lowercased())" }.joined(separator: " · ") }

    var body: some View {
        Button { onToggle() } label: {
            HStack(spacing: Style.Spacing.label) {
                Image(systemName: "terminal")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Command setup")
                        .font(.system(size: 13, weight: .medium))
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct TaskSetup: Surface {
    var panel: any Panel
    var model: any Model

    @State private var expanded = false

    var ref: Reference? { model.session.opened.document }
    var surface: AnySurface { .init(panel: panel, model: model) }
    var command: Reference? { ref.flatMap { Sheet.with($0, { $0.command }) ?? nil } }
    var parameters: [Parameter] { command.flatMap { Command.with($0, { $0.parameters }) } ?? [] }
    var rows: [ItemParams] { arguments.compactMap { $0.item(values[$0.name]) } }

    var arguments: [Argument] { parameters.filter {
        if case .argument(_, _, false, _) = $0 { true }
        else { false }
    }.compactMap(Argument.init) }

    var values: [String: Value] { ref.flatMap { Sheet.with($0, {
        if case .collection(let values)? = $0.data { values }
        else { [:] } }) } ?? [:]
    }

    var body: some View {
        if let ref, !rows.isEmpty {
            VStack(spacing: 0) {
                TaskSetupSummary(rows: rows, expanded: expanded) { expanded.toggle() }
                if expanded {
                    let controls = Argument.controls { key, value in
                        var values = values
                        values[key] = value
                        Sheet.update(ref) { $0.data = .collection(values) }
                    }
                    ForEach(rows) { row in
                        GroupDivider()
                        Factory.build(surface, params: row, controls: controls, layout: .group)
                    }
                }
            }
            .background(Style.Shape.card.fill(Style.Background.group))
        }
    }
}
