import SwiftUI
import AgencyRuntime


struct Badge: View {
    var icon: String
    var color: Color
    var glass: Bool
    var label: String
    var count: Int = 0
    var design: Design.Badge { .init(color: color) }
    var padding: (CGFloat, CGFloat) { glass ? (6, 4) : (2, 0) }

    init(icon: String, label: String, count: Int = 0, color: Color, glass: Bool = false) {
        self.icon = icon
        self.label = label
        self.count = count
        self.color = color
        self.glass = glass
    }

    var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(count > 0 ? design.foreground : Color.primary.opacity(0.4))

            Text("\(label) \(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(count > 0 ? .primary.opacity(0.9) : Color.primary.opacity(0.4))
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, padding.0)
        .padding(.vertical, padding.1)
        .contentShape(Capsule())
        .frame(height: 28)
        .frame(maxWidth: 44, maxHeight: 36)
    }

    @ViewBuilder  var body: some View {
        if glass { Group { GlassEffectContainer { badge.glassEffect(.regular, in: Capsule()) } } }
        else { Group { badge } }
    }
}

struct SelectionBadge: View {
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color(red: 0.36, green: 0.61, blue: 0.84) : Color.white.opacity(0.08))
            .frame(width: 24, height: 24)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: TypeScale.badgeCheck, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}

struct Filter: View {
    @Binding var text: String
    var placeholder = "Filter"

    var body: some View {
        HStack(alignment: .bottom) {
            HStack {
                TextField(placeholder, text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 13, weight: .light))
                    .padding(.horizontal, 12)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: 32)
            .frame(height: 32)
            .background(.black.opacity(0.26))
            .background(.ultraThickMaterial.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(lineWidth: 0.5).opacity(0.1))
            .glassEffect(.regular, in:RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

struct FilterControl: View {
    @Binding var text: String
    var placeholder = "Filter"

    var body: some View {
        HStack(alignment: .bottom) {
            HStack {
                TextField(placeholder, text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.opacity(0.6))
                    .font(.system(size: 13, weight: .light))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: 32)
            .frame(height: 32)
            .background(.black.opacity(0.26))
            .background(.ultraThickMaterial.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(lineWidth: 0.5).opacity(0.1))
            .glassEffect(.regular, in:RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .padding([.bottom, .horizontal], 8)
    }
}

struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var sheet: Reference? { agency.session.sheet }
    private var space: Reference? { agency.session.space }
    private var workspace: Reference { agency.session.workspace }

    var body: some View {
        ControlGroup {
            Button { agency.backward() } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.canGoBack)
            Button { agency.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct SpaceRow: View {
    @Environment(AgencyModel.self) var agency
    @State private var isHovered = false
    let ref: Reference
    let selected: Bool

    private var name: String {
        Workspace.with(ref) { $0.name } ?? Space.with(ref) { $0.name } ?? "Space"
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.accentColor.opacity(0.4) : Color.clear)
        }
        .onHover { isHovered = $0 }
    }
}

struct SpaceActionRow: View {
    @State private var isHovered = false
    let title: String
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.accentColor.opacity(0.4) : Color.clear)
        }
        .onHover { isHovered = $0 }
        .onTapGesture { action() }
    }
}

struct WorkspacesControls: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool
    @Binding var text: String
    @Binding var tab: Tab

    enum Tab: Hashable {
        case workspaces
        case defaults
    }

    private var spaces: [Reference] { Runtime.shared.workspaces }

    private func select(_ ref: Reference) {
        agency.select(ref)
        presented = false
    }

    var body: some View {
        TabView(selection: $tab) {
            VStack(alignment: .leading, spacing: 0) {
                Filter(text: $text)
                    .padding(.vertical, 6)

                VStack(spacing: 2) {
                    ForEach(spaces) { space in
                        SpaceRow(ref: space, selected: space == agency.session.workspace)
                            .onTapGesture { select(space) }
                    }
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)

                VStack(spacing: 2) {
                    SpaceActionRow(title: "New Space...") { }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
            .tabItem { Label("Workspaces", systemImage: "cube.transparent") }
            .tag(Tab.workspaces)
        }
        .frame(width: 220, height: 240)
    }
}

struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    private var ref: Reference { agency.session.space ?? agency.session.workspace }
    private var services: [Reference] { Workspace.with(agency.session.workspace, { $0.services }) ?? [] }
    private var selectedHarness: Reference? {
        if let service = agency.session.service, services.contains(service) { return service }
        return services.first
    }
    private var composition: Composition? { Runtime.shared.context(for: ref) }

    private var isRunning: Bool {
        composition?.state == .running
    }

    var body: some View {
        ControlGroup {
            HStack(alignment: .center, spacing: 0) {
                Group {
                    Button { } label: {
                        Image(systemName: Design.Component.icon(for: ref))
                            .foregroundStyle(.primary.opacity(0.9))
                            .font(.system(size: 11, weight: .semibold))
                        Text(Runtime.shared.get(ref).name)
                            .foregroundStyle(.primary.opacity(0.9))
                            .font(.system(size: 11))
                    }
                }

                Image(systemName: "chevron.compact.forward")
                    .foregroundStyle(.secondary.opacity(0.8))
                    .font(.system(size: 16))
                    .padding(.horizontal, 1)

                Group {
                    Menu {
                        if services.isEmpty { Text("No default services loaded") }
                        else {
                            ForEach(services) { ref in
                                Button { agency.session.service = ref } label: {
                                    Label(ref.name, systemImage: ref == selectedHarness ? "checkmark" : "arrow.2.squarepath")
                                }
                            }
                        }
                    } label: {
                        Button { } label: {
                            if let selectedHarness {
                                Image(systemName: Design.Component.icon(for: selectedHarness))
                                    .foregroundStyle(.primary.opacity(0.9))
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(Harness.with(selectedHarness, { $0 })?.name ?? "Select Harness")")
                                    .foregroundStyle(.primary.opacity(0.9))
                                    .font(.system(size: 11))
                            } else {
                                Text("Select Harness")
                                    .foregroundStyle(.primary.opacity(0.9))
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    .menuIndicator(.hidden)
                }

                Spacer()
                Spacer()

                Group {
                    Button { agency.process(service: selectedHarness) } label: {
                        Image(systemName: isRunning ? "circle.fill" : "play.fill")
                            .foregroundStyle(isRunning ? Design.Tint.running : .primary)
                    }
                    .disabled(agency.session.space == nil || selectedHarness == nil)
                    .help(isRunning ? "Process running" : "Start a process from this space")
                }
                .controlGroupStyle(.navigation)
            }
            .frame(width: 512)
            .glassEffect(.regular.tint(.black.opacity(0.05)))
        }
    }
}
