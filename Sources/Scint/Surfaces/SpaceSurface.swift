import SwiftUI


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
                    .foregroundStyle(Style.Foreground.primary)
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
                SpaceSection(name: "Spaces") {
                    Button { Action.createSpace(in: model.session.origin, model: model) } label: {
                        Image(systemName: "plus")
                            .labelsHidden()
                            .font(Typography.label)
                            .foregroundStyle(Style.Foreground.subtle)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                ForEach(spaces) { space in
                    HStack(spacing: Style.Spacing.md) {
                        Card(
                            ref: space,
                            style: .list,
                            onSelect: { model.select(space) },
                            isSelected: model.session.selection.selected(space)
                        )
                        if running(space) { RunningIndicator(size: .mini) }
                    }
                }

                if model.session.origin.type is Space.Type {
                    SpaceSection(name: "Materials") {
                        Button { Action.createMaterial(in: model.session.origin, model: model) } label: {
                            Image(systemName: "plus")
                                .font(Typography.label)
                                .foregroundStyle(Style.Foreground.subtle)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)

                    ForEach(model.session.materials) { material in
                        Card(
                            ref: material,
                            style: .list,
                            onSelect: { model.open(material) },
                            isSelected: model.session.selection.selected(material)
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
