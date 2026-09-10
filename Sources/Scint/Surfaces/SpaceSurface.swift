import SwiftUI


struct ProcessLine: View {
    let model: any Model
    let space: Reference
    let onOpen: (Reference) -> Void

    private var composition: Composition? { model.compose(space) }

    private func summary(_ transcript: Reference) -> String {
        let request = Transcript.with(transcript) { record -> String? in
            for entry in record.entries.reversed() {
                guard case .record(let chunk, _) = entry, chunk.origin.type is Material.Type
                        else { continue }
                let rendered = chunk.value.rendered
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !rendered.isEmpty { return rendered }
            }
            return nil
        } ?? nil

        return request ?? space.descriptor.name
    }

    @ViewBuilder private var divider: some View {
        Rectangle()
            .fill(Style.Border.group)
            .frame(height: 0.5)
    }

    var body: some View {
        if let composition, case .working = composition.state {
            let transcript = composition.transcript

            divider

            HStack(alignment: .center, spacing: Style.Spacing.lg) {
                RunningIndicator()
                    .frame(width: Style.Dimension.iconLarge, height: Style.Dimension.iconLarge)

                Text(summary(transcript))
                    .font(Typography.cardRow)
                    .foregroundStyle(Style.Foreground.base)
                    .lineLimit(Style.Limit.singleLine)

                Text("Working")
                    .font(Typography.label)
                    .foregroundStyle(Style.Tint.space)
                    .lineLimit(Style.Limit.singleLine)

                Spacer(minLength: Style.Spacing.md)

                Button { onOpen(transcript) } label: {
                    Text("Open Transcript")
                        .font(Typography.label)
                        .foregroundStyle(Style.Foreground.subtle)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the transcript for this space")
            }
            .frame(maxWidth: .infinity, minHeight: Style.Spacing.rowDetailHeight, alignment: .leading)

            divider
        }
    }
}

struct SpaceHeader: View {
    let ref: Reference

    var body: some View {
        let name = ref.descriptor.name
        let description = ref.descriptor.description

        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Iconography
                    .icon(for: ref, size: 16)
                    .frame(alignment: .leading)
                    .padding(.top, 10)
                    .padding(.trailing, 4)

                Text(name)
                    .frame(alignment: .leading)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Style.Foreground.base)
                    .padding(.top, 10)
            }

            VStack(alignment: .center) {
                Text(description.isEmpty ? "Add a description..." : description)
                    .frame(alignment: .leading)
                    .foregroundStyle(
                        description.isEmpty ? Style.Foreground.faint : Style.Foreground.subtle
                    )
                    .font(.system(size: 12))
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SpaceSection<Action: View>: View {
    let name: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(alignment: .center) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: Style.Spacing.md)
            action
        }
    }
}

struct SpaceSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }

    func running(_ space: Reference) -> Bool {
        guard let composition = model.compose(space) else { return false }
        if case .working = composition.state { return true }
        return false
    }

    var body: some View {
        let spaces = Array(Space.with(origin, { $0.spaces }) ?? Workspace.with(origin, { $0.spaces }) ?? [])

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Style.Spacing.lg) {
                ProcessLine(model: model, space: model.session.origin) { transcript in
                    model.select(transcript)
                }

                SpaceSection(name: "Spaces") {
                    Button { Action.createMaterial(in: model.session.origin, model: model) } label: {
                        Label("New Space", systemImage: "plus")
                            .font(Typography.label)
                            .foregroundStyle(Style.Foreground.subtle)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                ForEach(spaces) { space in
                    HStack(spacing: Style.Spacing.md) {
                        ReferenceCard(
                            ref: space,
                            isSelected: model.session.selected.selected(space),
                            onSelect: { model.select(space) }
                        )
                        if running(space) { RunningIndicator(size: .mini) }
                    }
                }


                if model.session.origin.type is Space.Type {
                    SpaceSection(name: "Materials") {
                        Button { Action.createMaterial(in: model.session.origin, model: model) } label: {
                            Label("New Material", systemImage: "plus")
                                .font(Typography.label)
                                .foregroundStyle(Style.Foreground.subtle)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)

                    ForEach(model.session.materials) { material in
                        ReferenceCard(
                            ref: material,
                            isSelected: model.session.selected.selected(material),
                            onSelect: { model.open(material) }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding([.horizontal, .top], 12)
            .padding(.bottom, Style.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
