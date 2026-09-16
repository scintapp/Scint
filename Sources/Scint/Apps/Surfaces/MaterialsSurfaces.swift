import SwiftUI


struct MaterialRow: Surface {
    let ref: Reference
    var panel: any Panel
    var model: any Model

    var body: some View {
        Button { model.open(ref) } label: {
            HStack(spacing: Style.Spacing.md) {
                Iconography.icon(for: ref).frame(width: 18)
                Text(Card.text(for: ref).name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(Typography.row)
            .foregroundStyle(Style.Foreground.primary)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Card.text(for: ref).name)
    }
}

struct MaterialHeader: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var collapsed: Bool { state.collapsed.contains(ref) }
    var title: String { heading(ref) ?? ref.descriptor.name }
 
    private func heading(_ ref: Reference) -> String? {
        guard case .text(_, let text)? = Material.with(ref, { $0.blocks.first }) ?? nil else { return "" }
        guard let line = text.split(separator: "\n", omittingEmptySubsequences: false).first,
              line.hasPrefix("# ") else { return nil }
        let title = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    @Binding var state: PanelState

    var body: some View {
        HStack(alignment: .center, spacing: Style.Spacing.lg) {
            Button {
                withAnimation(.smooth(duration: Style.Duration.interaction)) {
                    if collapsed { state.collapsed.remove(ref) }
                    else { state.collapsed.update(with: ref) }
                }
            } label: {
                HStack(alignment: .center, spacing: Style.Spacing.lg) {
                    Image(systemName: "chevron.down")
                        .foregroundStyle(Style.Foreground.faint)
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(collapsed ? -90 : .zero))
                        .frame(width: Style.Dimension.control, height: Style.Dimension.control)

                    if collapsed { Text(title).font(Typography.display) }
                }
            }
            .buttonStyle(.plain)

            if !collapsed { Text(title).font(Typography.cardTitle) }

            Spacer()

            Button { model.session.open(ref) } label: {
                Image(systemName: "rectangle.righthalf.inset.fill.arrow.right")
                    .foregroundStyle(Style.Foreground.faint)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: Style.Dimension.control, height: Style.Dimension.control)
                    .contentShape(Style.Shape.medium)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: Style.Spacing.cardHeight)
        .padding(.horizontal, Style.Spacing.md)
        .padding(.vertical, Style.Spacing.sm)
    }
}

struct MaterialFooter: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var words: String { "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")" }
    var tasks: String { "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")" }

    var metrics: (words: Int, completedTasks: Int, totalTasks: Int) {
        Material.with(ref) { material in
            let words = material.rendered.split(whereSeparator: { $0.isWhitespace }).count
            let tasks = material.blocks.compactMap { block -> Bool? in
                guard case .task(_, _, let completed) = block else { return nil }
                return completed }
            return (words, tasks.filter { $0 }.count, tasks.count)
        } ?? (0, 0, 0)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Style.Spacing.lg) {
            Text(tasks)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: 32)
        .frame(alignment: .center)
        .foregroundStyle(Style.Foreground.faint)
        .font(.callout)
    }
}

struct MaterialSurface: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var body: some View {
        ScrollView {
            EditorView(
                ref,
                sizing: .fitsContent,
                autofocus: false,
                onFocus: { model.select(ref) },
                onOpenLink: { link in
                switch link {
                case .reference(let reference): model.open(reference)
                case .url(let url): NSWorkspace.shared.open(url)
                }
            })
            .id(ref)
            .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .center)
            .padding(.horizontal, Style.Spacing.xxl)
            .padding(.top, Style.Spacing.xxl)
            .padding(.bottom, Style.Spacing.xxxl)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .simultaneousGesture(TapGesture().onEnded { model.open(ref) })
    }
}

struct MaterialsSurface: Surface {
    var panel: any Panel
    var model: any Model

    var materials: [Reference] {
        guard let ref = model.session.space, let materials = Space.with(ref, { $0 })?.materials
        else { return [] }
        return materials
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Style.Spacing.xs) {
                ForEach(materials) { ref in
                    MaterialSurface(ref: ref, panel: panel, model: model)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
    }
}
