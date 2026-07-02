import AgencyRuntime
import SwiftUI


private struct PaletteIndexedComponent: Identifiable {
    let component: ComponentParams
    let startIndex: Int

    var id: AnyHashable { component.id }

    static func index(_ components: [ComponentParams]) -> [PaletteIndexedComponent] {
        var offset = 0
        return components.map { component in
            defer { offset += component.items.count }
            return PaletteIndexedComponent(component: component, startIndex: offset)
        }
    }
}

private struct PaletteComponentSection: View {
    let component: ComponentParams
    let startIndex: Int
    let selectedIndex: Int
    let controls: Controls
    let onSelectIndex: (Int) -> Void

    var body: some View {
        if !component.items.isEmpty {
            if component.header && !component.name.isEmpty {
                Text(component.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
            }

            ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                let absoluteIndex = startIndex + offset
                PaletteRow(
                    item: item,
                    isSelected: absoluteIndex == selectedIndex,
                    onTap: {
                        onSelectIndex(absoluteIndex)
                        controls.onSelect?(item)
                    }
                )
                .id(item.id)
            }
        }
    }
}

private struct PaletteEmptyState: View {
    var body: some View {
        VStack {
            Text("No results")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

@Observable final class PaletteContent: Panel {
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        agency.studio.palette.controls(agency)
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        agency.studio.palette.parameters(agency)
    }

    func view(_ agency: AgencyModel) -> some View {
        let params = parameters(agency)
        let controls = controls(agency)
        let indexedComponents = PaletteIndexedComponent.index(params.components)
        let flatItems = params.components.flatMap { $0.items }

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if flatItems.isEmpty {
                        PaletteEmptyState()
                    } else {
                        ForEach(indexedComponents) { indexed in
                            PaletteComponentSection(
                                component: indexed.component,
                                startIndex: indexed.startIndex,
                                selectedIndex: agency.studio.palette.index,
                                controls: controls,
                                onSelectIndex: { agency.studio.palette.index = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: agency.studio.palette.index) { _, index in
                guard flatItems.indices.contains(index) else { return }
                proxy.scrollTo(flatItems[index].id, anchor: .center)
            }
        }
    }
}
