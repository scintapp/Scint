import AgencyRuntime
import SwiftUI


struct Catalog: View {
    @State private var query = ""
    @State private var selectedMode: CatalogMode = .components
    @State private var selectedComponent: Component = .control

    let placeholder: String
    let components: [Component]
    let onSelectComponent: (Component) -> Void
    let items: (Component) -> AnyView

    init<Items: View>(
        placeholder: String = "Search Components",
        components: [Component] = Component.allCases,
        onSelectComponent: @escaping (Component) -> Void = { _ in },
        @ViewBuilder items: @escaping (Component) -> Items
    ) {
        self.placeholder = placeholder
        self.components = components
        self.onSelectComponent = onSelectComponent
        self.items = { AnyView(items($0)) }
    }

    init(
        placeholder: String = "Search Components",
        components: [Component] = Component.allCases,
        onSelectComponent: @escaping (Component) -> Void = { _ in }
    ) {
        self.init(
            placeholder: placeholder,
            components: components,
            onSelectComponent: onSelectComponent
        ) { _ in
            EmptyView()
        }
    }

    enum CatalogMode: String, CaseIterable, Identifiable {
        case components
        case details

        var id: Self { self }

        var symbol: String {
            switch self {
            case .components: "rectangle.stack"
            case .details: "info.circle"
            }
        }
    }

    enum Component: String, CaseIterable, Identifiable {
        case files
        case bookmark
        case script
        case skill
        case control
        case service

        var id: Self { self }

        var title: String {
            switch self {
            case .files: "Files"
            case .bookmark: "Bookmarks"
            case .script: "Scripts"
            case .skill: "Skills"
            case .control: "Controls"
            case .service: "Services"
            }
        }

        var symbol: String {
            switch self {
            case .files: "folder"
            case .bookmark: "link"
            case .script: "scroll"
            case .skill: "sparkles"
            case .control: "switch.2"
            case .service: "app.connected.to.app.below.fill"

            }
        }

        var tint: Color {
            switch self {
            case .bookmark: Design.Tint.success
            case .files: Design.Tint.input
            case .script: Design.Tint.sheet
            case .skill: Design.Tint.input
            case .control: Design.Tint.control
            case .service: Design.Tint.error
            }
        }

        static func icon(for ref: Reference) -> String {
            Design.Component.icon(for: ref)
        }
    }

    private var visibleComponents: [Component] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return components }
        return components.filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    var body: some View {
        VSplitView {
            CatalogCategoryPane(
                query: $query,
                selectedMode: $selectedMode,
                selectedComponent: $selectedComponent,
                placeholder: placeholder,
                components: visibleComponents,
                onSelect: select
            )
            .frame(minHeight: 120, idealHeight: 420)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.78))
                    .frame(height: 1)
            }

            CatalogItemsPane {
                items(selectedComponent)
            }
            .frame(minHeight: 160)
        }
        .background(Design.Background.panels)
    }

    private func select(_ component: Component) {
        selectedComponent = component
        onSelectComponent(component)
    }
}

private struct CatalogCategoryPane: View {
    @Binding var query: String
    @Binding var selectedMode: Catalog.CatalogMode
    @Binding var selectedComponent: Catalog.Component

    let placeholder: String
    let components: [Catalog.Component]
    let onSelect: (Catalog.Component) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedMode) {
                ForEach(Catalog.CatalogMode.allCases) { mode in
                    Image(systemName: mode.symbol)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)

            CatalogSearchField(text: $query, placeholder: placeholder)

            CategoryBar(
                categories: components,
                title: \.title,
                symbol: \.symbol,
                tint: \.tint,
                selection: Binding(
                    get: { selectedComponent },
                    set: { onSelect($0) }
                )
            )
        }
    }
}

private struct CatalogSearchField: View {
    @Binding var text: String

    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.leading, 12)
        .frame(height: 38)
        .background(.primary.opacity(0.10), in: Capsule())
        .padding(.horizontal, 10)
    }
}

private struct CatalogItemsPane<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }
}

struct CatalogItemRow: View {
    let title: String
    let symbol: String
    var selected = false
    var tint: Color = .purple
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.9))
                    .frame(width: 21, height: 21)
                    .background(tint.opacity(0.90), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.8) : Color.clear)
        }
    }
}

struct CategoryBar<Category: Hashable & Identifiable>: View {
    let categories: [Category]
    let title: (Category) -> String
    let symbol: (Category) -> String
    let tint: (Category) -> Color
    @Binding var selection: Category

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    CategoryPill(
                        title: title(category),
                        symbol: symbol(category),
                        tint: tint(category),
                        selected: selection == category
                    ) {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            selection = category
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

private struct CategoryPill: View {
    let title: String
    let symbol: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? .white : .primary.opacity(0.75))
                    .frame(width: 18, height: 18)

                if selected {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity
                            )
                        )
                }
            }
            .padding(.horizontal, selected ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? tint.opacity(0.4) : Color.primary.opacity(0.08))
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}


