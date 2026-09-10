import SwiftUI


struct MaterialHeader: View {
    var model: any Model
    var ref: Reference

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
                        .font(.system(size: Style.Dimension.icon, weight: .semibold))
                        .rotationEffect(.degrees(collapsed ? -90 : .zero))
                        .frame(width: Style.Dimension.control, height: Style.Dimension.control)

                    if collapsed { Text(title).font(Typography.display) }
                }
                .contentShape(Style.Shape.medium)
            }
            .buttonStyle(.plain)

            if !collapsed { Text(title).font(Typography.display) }

            Spacer()

            Button { model.session.open(ref) } label: {
                Image(systemName: "arrow.down.left.and.arrow.up.right")
                    .foregroundStyle(Style.Foreground.faint)
                    .font(.system(size: Style.Dimension.icon, weight: .medium))
                    .frame(width: Style.Dimension.control, height: Style.Dimension.control)
                    .contentShape(Style.Shape.medium)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: Style.Spacing.cardHeight)
        .padding(.horizontal, Style.Spacing.lg)
        .padding(.vertical, Style.Spacing.md)
    }
}

struct MaterialFooter: View {
    var model: any Model
    var ref: Reference

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
    var panel: any Panel
    var model: any Model

    var ref: Reference

    var maximized: Bool { model.session.opened.material == ref }

    func content(_ minHeight: CGFloat) -> some View {
        ScrollView {
            VStack {
                EditorComponent(ref, autofocus: false, active: model.session.selected.content == ref, minHeight: minHeight) { id in
                    if let ref = id as? Reference { model.select(ref) }
                    else if let id = id as? UUID { model.select(ref, entry: id, url: nil) }
                }
                .id(ref)
                .frame(maxWidth: Style.Spacing.contentMaxWidth, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, Style.Spacing.xxl)
                .padding(.top, Style.Spacing.xxl)
                .padding(.bottom, Style.Spacing.xxxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .scrollDisabled(!maximized)
        .simultaneousGesture(TapGesture().onEnded { model.select(ref) })
    }

    var body: some View {
        if maximized { GeometryReader { proxy in content(proxy.size.height) } }
        else { content(0) }
    }
}

struct MaterialsSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var material: Reference? { model.session.opened.material }
    var materials: [Reference] { model.session.materials }

    @State var state: PanelState

    init(panel: any Panel, model: any Model, state: PanelState) {
        self.panel = panel
        self.model = model
        self.state = state
        state.expanded = Set(materials)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Style.Spacing.xxl) {
                ForEach(materials) { material in
                    VStack {
                        MaterialHeader(model: model, ref: material, state: $state)
                        if !state.collapsed.contains(material) {
                            MaterialSurface(panel: panel, model: model, ref: material)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .top)
                    .frame(maxWidth: Style.Spacing.contentMaxWidth)
                    .background {
                        Style.Shape.large
                            .fill(Style.Background.panel)
                            .strokeBorder(Style.Border.base, lineWidth: 0.5, antialiased: true)
                    }
                    .clipShape(Style.Shape.large)
                }
            }
            .padding(.vertical, Style.Spacing.xxxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
    }
}
