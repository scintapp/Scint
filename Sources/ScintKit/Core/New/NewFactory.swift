import SwiftUI
import UniformTypeIdentifiers


/// Sketch implementation of the rebuilt factory.
///
/// Three methods, one per tier, and nothing else. No helpers, no utilities, no extra overloads —
/// whatever a tier needs to do its own job is declared inside that tier's method, so the surface
/// area of this type is exactly the three doors it is supposed to have. They are declared as
/// closures rather than nested functions because a `@ViewBuilder` body accepts variable
/// declarations but not function declarations.
///
/// Each method owns its layer and delegates rather than reaching down. The panel maps out the
/// composition by calling the section and item methods; a section's own row is an item, so it
/// hands that to the item method instead of assembling components itself; only the item method
/// knows how a component or a control becomes a view.
///
/// The rule underneath: params carry identity and intent, the runtime carries data, views resolve.
/// A `.text(.name)` resolves through the reference at render, selection comes off the session and
/// expansion off the panel state the surface already carries, and depth is traversal state rather
/// than something params describe.
///
/// One deviation from the sketch, flagged rather than papered over: the panel entry takes a
/// surface instead of a panel. `Panel` alone cannot reach a model and the panel tier has to
/// resolve its children; `Surface` is the only thing carrying both.
@MainActor enum NewFactory {

    // MARK: - Panel

    /// The frame, and the orchestrator. Panel type decides what kind of container this is: a
    /// fixed panel is an ordinary docked surface, a floating one is the search-panel variety.
    /// They are one category of thing so that toggling between them is a change of param rather
    /// than a change of construction.
    @ViewBuilder static func build(_ surface: some Surface, panel: NewParams.Panel) -> some View {
        let compose: (NewParams) -> AnyView = { params in
            switch params {
                case .surface(.section(let section)): AnyView(build(surface, section: section))
                case .surface(.item(let item)): AnyView(build(surface, item: item))
                case .panel(let nested): AnyView(build(surface, panel: nested))
            }
        }

        let composition = ScrollView {
            LazyVStack(alignment: .leading, spacing: Style.Spacing.xs) {
                ForEach(Array(panel.params.enumerated()), id: \.offset) { _, params in
                    compose(params)
                }
            }
            .padding(Style.Spacing.md)
        }
        .frame(
            minWidth: panel.sizing.min?.width,
            idealWidth: panel.sizing.ideal.width,
            maxWidth: panel.sizing.max?.width,
            minHeight: panel.sizing.min?.height,
            idealHeight: panel.sizing.ideal.height,
            maxHeight: panel.sizing.max?.height
        )

        switch panel.type {
            case .fixed:
                composition
                    .background(Style.Background.base)

            case .floating:
                composition
                    .background(Style.Background.overlay)
                    .clipShape(Style.Shape.panel)
                    .overlay(Style.Shape.panel.strokeBorder(Style.Border.base, lineWidth: Style.Dimension.border))
                    .shadow(color: .black.opacity(Style.Opacity.faint), radius: Style.Spacing.xl, y: Style.Spacing.md)
        }
    }

    // MARK: - Section

    /// The region. Chooses scaffolding, resolves its own expansion, and delegates: its header row
    /// is described by the same components and controls an item carries, so the item method builds
    /// it, and its children go back through whichever method their case names.
    @ViewBuilder static func build(_ surface: some Surface, section: NewParams.Section, depth: Int = 0) -> some View {
        let toggle: () -> Void = {
            guard let ref = section.ref else { return }
            surface.setExpanded(AnyHashable(ref))
        }

        let compose: (NewParams.Surface, Int) -> AnyView = { node, depth in
            switch node {
                case .item(let item): AnyView(build(surface, item: item, depth: depth))
                case .section(let nested): AnyView(build(surface, section: nested, depth: depth))
            }
        }

        /// The section's own row, expressed as what it is: an item.
        let header: (Bool) -> NewParams.Item = { expanded in
            let disclosure: [NewParam.Control] = section.params.isEmpty || section.ref == nil
                ? []
                : [.disclosure(expanded, toggle)]

            return .init(
                id: section.id,
                ref: section.ref,
                layout: .row,
                components: section.components,
                controls: disclosure + section.controls
            )
        }

        // Tree nodes start closed; a label-only region is always open.
        let expanded = section.ref.map { surface.isExpanded(AnyHashable($0)) } ?? true

        /// A section with nothing of its own to say draws no header row. Without this a purely
        /// structural section renders an empty, padded row above its children.
        let titled = !section.components.isEmpty || !section.controls.isEmpty

        switch section.layout {
            case .list:
                NewList {
                    if titled {
                        build(surface, item: header(expanded), depth: depth)
                            .environment(\.newRowStyle, section.ref == nil ? .listHeader : .list)
                    }
                } content: {
                    if expanded {
                        ForEach(section.params) { node in
                            compose(node, section.ref == nil ? depth : depth + 1)
                        }
                    }
                }

            case .group:
                NewGroup {
                    if titled { build(surface, item: header(expanded), depth: depth) }
                } content: {
                    if expanded {
                        ForEach(Array(section.params.enumerated()), id: \.element.id) { index, node in
                            if index > 0 { NewDivider() }
                            compose(node, depth)
                        }
                    }
                }

            case .grid, .table:
                EmptyView()
        }
    }

    // MARK: - Item

    /// The leaf, and the only tier that knows what a component or a control looks like. Everything
    /// needed to answer that is declared here.
    @ViewBuilder static func build(_ surface: some Surface, item: NewParams.Item, depth: Int = 0) -> some View {
        let tint: Color = item.ref.map { Iconography.icon(for: $0).tint } ?? Style.Tint.space

        let component: (NewParam.Component) -> AnyView = { component in
            switch component {
                case .icon:
                    guard let ref = item.ref else { return AnyView(EmptyView()) }
                    return AnyView(Iconography.icon(for: ref, size: Style.Dimension.icon))

                case .model(let model, _):
                    let icon = Iconography.model(model)
                    return AnyView(
                        Iconography.Icon(symbol: icon.symbol, tint: icon.tint, sizing: Style.Dimension.icon)
                    )

                case .symbol(let name, let tint, _):
                    return AnyView(Iconography.Icon(symbol: name, tint: tint, sizing: Style.Dimension.icon))

                case .text(.name):
                    return AnyView(
                        Text(item.ref?.descriptor.name ?? "")
                            .modifier(NewTitleStyle())
                            .layoutPriority(1)
                    )

                case .text(.literal(let value)):
                    return AnyView(Text(value).modifier(NewTitleStyle()).layoutPriority(1))

                case .text(.description):
                    return AnyView(Text(item.ref?.descriptor.description ?? "").modifier(NewDetailStyle()))

                case .text(.detail(let value)):
                    return AnyView(Text(value).modifier(NewDetailStyle()))

                case .badge(.count(let value), _):
                    return AnyView(Badge(label: "\(value)", tint: tint, outlined: true))

                case .badge(.label(let value), _):
                    return AnyView(Badge(label: value, tint: tint, outlined: true))

                case .badge(.tasks, _):
                    guard let ref = item.ref else { return AnyView(EmptyView()) }
                    let counts = Material.with(ref) { material -> ComponentCount in
                        var counts = ComponentCount()
                        counts.include(material.blocks)
                        return counts
                    }
                    guard let counts, counts.totalTasks > 0 else { return AnyView(EmptyView()) }
                    return AnyView(
                        Badge(
                            label: "\(counts.completedTasks)/\(counts.totalTasks)",
                            tint: Style.Tint.task,
                            outlined: true
                        )
                    )

                case .chip(let label, _):
                    guard let ref = item.ref else { return AnyView(EmptyView()) }
                    return AnyView(Chip(ref: ref, label: label.isEmpty ? nil : label))

                case .card:
                    guard let ref = item.ref else { return AnyView(EmptyView()) }
                    return AnyView(Card(ref: ref, style: .group))

                case .block:
                    guard let ref = item.ref else { return AnyView(EmptyView()) }
                    return AnyView(TextBlock(content: ref.descriptor.description))
            }
        }

        let control: (NewParam.Control) -> AnyView = { control in
            switch control {
                case .action:
                    return AnyView(EmptyView())

                case .button(let label, let run):
                    return AnyView(
                        Button(label, action: run)
                            .buttonStyle(.plain)
                            .font(Typography.label)
                            .foregroundStyle(Style.Foreground.subtle)
                    )

                case .date(let value, let set):
                    return AnyView(
                        DatePicker("", selection: Binding(get: { value }, set: set))
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    )

                case .disclosure(let expanded, let toggle):
                    return AnyView(NewDisclosure(expanded: expanded, onToggle: toggle))

                case .field(let value, let set):
                    return AnyView(
                        TextField("", text: Binding(get: { value }, set: set))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(Typography.row)
                            .frame(width: 112)
                    )

                case .load(let label, let references, let pick):
                    return AnyView(NewLoadMenu(label: label, references: references, onPick: pick))

                case .picker(let options, let selected, let set):
                    return AnyView(NewPicker(options: options, selected: selected, onChange: set))

                case .range(let options, let selected, let set):
                    return AnyView(NewRangePicker(options: options, selected: selected, onChange: set))

                case .toggle(let isOn, let set):
                    return AnyView(
                        Toggle("", isOn: Binding(get: { isOn }, set: set))
                            .labelsHidden()
                            .controlSize(.small)
                    )
            }
        }

        let placement: (NewParam.Component) -> NewParam.Position = { component in
            switch component {
                case .badge(_, let position), .chip(_, let position): position
                case .icon(let position), .model(_, let position), .symbol(_, _, let position): position
                case .block, .card, .text: .leading
            }
        }

        /// Where a control sits. Disclosure leads its row, everything else trails it, and
        /// activation draws nothing — it is the row's own gesture.
        let position: (NewParam.Control) -> NewParam.Position? = { control in
            switch control {
                case .action: nil
                case .disclosure: .stack
                case .button, .date, .field, .load, .picker, .range, .toggle: .trailing
            }
        }

        let activation: () -> (() -> Void)? = {
            for control in item.controls { if case .action(let run) = control { return run } }
            return nil
        }

        let detailed = item.components.contains { component in
            switch component {
                case .text(.description), .text(.detail): true
                default: false
            }
        }

        let layered: [AnyView] = item.components.filter { placement($0) == .stack }.map(component)
            + item.controls.filter { position($0) == .stack }.map(control)

        NewRow(
            selected: item.ref.map { surface.model.session.selection.selected($0) } ?? false,
            detailed: detailed,
            indent: CGFloat(depth) * Style.Spacing.listIndent,
            onSelect: activation()
        ) {
            if layered.count > 1 { NewStack(resting: layered[0], active: layered[1]) }
            else if let only = layered.first { only }

            ForEach(Array(item.controls.filter { position($0) == .leading }.enumerated()), id: \.offset) { _, entry in
                control(entry)
            }

            switch item.layout {
                case .row:
                    HStack(spacing: Style.Spacing.md) {
                        ForEach(Array(item.components.filter { placement($0) == .leading }.enumerated()), id: \.offset) { _, entry in
                            component(entry)
                        }
                    }

                case .column:
                    VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                        ForEach(Array(item.components.filter { placement($0) == .leading }.enumerated()), id: \.offset) { _, entry in
                            component(entry)
                        }
                    }
            }

            Spacer(minLength: Style.Spacing.md)

            ForEach(Array(item.components.filter { placement($0) == .trailing }.enumerated()), id: \.offset) { _, entry in
                component(entry)
            }

            ForEach(Array(item.controls.filter { position($0) == .trailing }.enumerated()), id: \.offset) { _, entry in
                control(entry)
            }
        }
        .onDrop(of: item.ref.map(ReferenceTransfer.dropTypes) ?? [], isTargeted: nil) { providers in
            guard let ref = item.ref else { return false }
            return ReferenceTransfer.handle(providers, target: ref)
        }
        .modifier(NewDraggable(reference: item.ref))
    }
}
