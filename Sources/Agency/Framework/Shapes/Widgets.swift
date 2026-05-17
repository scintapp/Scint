import SwiftUI
import AgencyRuntime


struct ActionRow: View {
    @State private var isHovered = false
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Text(title)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovered ? Color.gray : .clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}

struct PanelFilter: View {
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

struct SpaceRow: View {
    @Environment(AgencyModel.self) var agency
    @State private var isHovered = false
    let ref: Reference
    let selected: Bool

    private var name: String { Space.with(ref) { $0.name } ?? "Space" }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.bottom, 1)

                Text("No Pending Tasks")
                    .font(.system(size: 9, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onHover { isHovered = $0 }
        }
    }
}

struct SpaceDropdown: View {
    @Environment(AgencyModel.self) var agency
    @Binding var isPresented: Bool
    @Binding var text: String

    private var currentSpace: Reference? {
        agency.session.space
    }

    private func select(_ ref: Reference) { }

    var body: some View {
        VStack {
            PanelFilter(text: $text)

            if let current = currentSpace {
                SpaceRow(ref: current, selected: true)
                    .onTapGesture { select(current) }
            }
            ActionRow(title: "New Space") { }
        }
        .padding(8)
        .frame(width: 300)
    }
}

public struct SpaceControls: View {
    @Environment(AgencyModel.self) var agency
    @State private var text = ""
    @State private var isPresented = false
    public init() {}

    var dropdown: some View {
        let currentSpace = agency.session.space
        return VStack {
            PanelFilter(text: $text)

            SpaceRow(ref: currentSpace, selected: true)
                .onTapGesture { agency.select(currentSpace) }
        ActionRow(title: "New Space") { }
        }
        .padding(8)
        .frame(width: 300)
    }

    public var body: some View {
        let name = Space.with(agency.session.space, { $0 })?.name ?? "nil"

        VStack(alignment: .leading) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .padding(.top, 2)

            Text("No Pending Tasks")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.leading, 4)
        .frame(maxWidth: 220)
        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture { isPresented.toggle() }
        .popover(isPresented: $isPresented) {
            SpaceDropdown(isPresented: $isPresented, text: $text)
        }
    }
}

struct RuntimeControls: View {
    @Environment(AgencyModel.self) var agency

    var stop: some View {
        Button {

        } label: {
            Image(systemName: "stop.fill")
        }
        .help("Stop the active boundary")
    }

    var start: some View {
        Button { } label: {
            Image(systemName: "play.fill")
        }
        .help("Start the active boundary")
    }

    var body: some View {
        HStack(spacing: 0) {
            start
        }
        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
    }
}

public struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    public init() {}

    public var body: some View {
        ControlGroup {
            HStack {
            }
            .padding(.horizontal, 12)
            .background(.clear)
        }
        .frame(width: 400)
        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
        .glassEffect(.regular)
    }
}

struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        HStack(spacing: 4) {
            Group {
                Button { agency.backward() } label: { Image(systemName: "chevron.backward") }
                    .disabled(!agency.session.canGoBack)

                Divider().frame(height: 18)

                Button { agency.forward() } label: { Image(systemName: "chevron.forward") }
                    .disabled(!agency.session.canGoForward)
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 17, weight: .light))
            .buttonStyle(.automatic)
            .buttonBorderShape(.circle)
        }
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

//struct LibraryToggle: View {
//    @State var isPresented: Bool = false
//
//    public var body: some View {
//        Button {  } label: {
//            Image(systemName: "building.columns")
//                .font(.system(size: 14, weight: .medium))
//                .foregroundStyle(.white)
//                .help("Open the library panel.")
//        }
//        .labelsHidden()
//    }
//}

//struct NavigatorToggle: View {
//    @Binding var presented: Bool
//    public init(presented: Binding<Bool>) { _presented = presented }
//
//    public var body: some View {
//        HStack(spacing: 0) {
//            if presented {
//                Button {
//                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
//                    presented.toggle()
//                } label: {
//                    Image(systemName: "sidebar.left")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(.white)
//                        .buttonStyle(.plain)
//                }
//            } else {
//                Button {
//                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
//                    presented.toggle()
//                } label: {
//                    Image(systemName: "sidebar.left")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(.white)
//                }
//            }
//        }
//        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
//    }
//}

struct ConsoleToggle: View {
    @Binding var presented: Bool

    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "dock.rectangle")
                .frame(maxWidth: 28, maxHeight: 28, alignment: .center)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(presented ? Color.secondary.opacity(0.8) : Color.primary.opacity(0.85))
                .help(presented ? "Hide console." : "Show console.")
        }
        .buttonStyle(.plain)
        .labelsHidden()
    }
}

struct DetailsToggle: View {
    @Binding var presented: Bool

    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "square.fill.text.grid.1x2")
                .help(presented ? "Hide boundary details" : "Show boundary details")
        }
        .buttonStyle(.automatic)
        .buttonBorderShape(.circle)
        .labelsHidden()
    }
}

//struct InspectorToggle: View {
//    @Binding var presented: Bool
//
//    init(presented: Binding<Bool>) { _presented = presented }
//
//    var body: some View {
//        HStack(spacing: 0) {
//            if presented {
//                Button { presented.toggle() } label: {
//                    Image(systemName: "sidebar.right")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(.white)
//                        .buttonStyle(.plain)
//                }
//            } else {
//                Button { presented.toggle() } label: {
//                    Image(systemName: "sidebar.right")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(.white)
//                }
//            }
//        }
//        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
//    }
//}

//struct SidebarModeToggle: View {
//    @Environment(AgencyModel.self) var agency

//    func toggle() -> some View {
//        HStack(spacing: 0) {
//            Button {
//                agency.
//                agency.sidebar.presented = true
//            } label: {
//                Image(systemName: agency.sidebar.composerImage)
//                    .frame(maxWidth: 36, maxHeight: 36, alignment: .center)
//            }
//            .id("composer")
//            Button {
//                agency.sidebar.active = .inspector
//                agency.sidebar.presented = true
//            } label: {
//                Image(systemName: agency.sidebar.inspectorImage)
//                    .frame(maxWidth: 36, maxHeight: 36, alignment: .center)
//            }
//            .id("inspector")
//        }
//    }

//    func picker() -> some View {
//        HStack(spacing: 0) {
//            Button {
//                if agency.sidebar.active == .composer {
//                    agency.sidebar.presented = false
//                } else {
//                    agency.sidebar.active = .composer
//                }
//            } label: {
//                Image(systemName:agency.sidebar.composerImage)
//            }
//            .id("composer")
//            .background(
//                agency.sidebar.active == .composer ?
//                Color.secondary.opacity(0.2) : .secondary.opacity(0.0),
//                in: .ellipse.inset(by: 4)
//            )
//
//            Button {
//                if agency.sidebar.active == .inspector {
//                    agency.sidebar.presented = false
//                } else {
//                    agency.sidebar.active = .inspector
//                }
//            } label: {
//                Image(systemName: agency.sidebar.inspectorImage)
//                    .frame(maxWidth: 36, maxHeight: 36, alignment: .center)
//            }
//            .id("inspector")
//            .background(
//                agency.sidebar.active == .inspector ?
//                Color.secondary.opacity(0.2) : .secondary.opacity(0.0),
//                in: .ellipse.inset(by: 2)
//            )
//
//        }
//    }

//    @ViewBuilder var body: some View {}
//}

//struct QuickActions: View {
//    @Environment(AgencyModel.self) var agency
//    @Bindable var content: Content
//    var boundary: Reference? { agency.session.boundary }
//
//    var body: some View {
//        HStack {
//            Menu {
//                if boundary != nil {
//                    Button { } label: { Label("New Boundary", systemImage: "plus.app") }
//                    Button { } label: { Label("New Sheet", systemImage: "square.and.pencil") }
//                    Divider()
//                }
//            } label: {
//                Image(systemName: "plus")
//                    .font(.system(size: 17, weight: .light))
//                    .foregroundStyle(.tertiary)
//            }
//            .menuIndicator(.hidden)
//            .menuStyle(.borderlessButton)
//            .controlSize(.large)
//
//            DetailsToggle(presented: $content.presented)
//                .buttonStyle(.plain)
//                .controlSize(.extraLarge)
//        }
//        .frame(maxHeight: 28, alignment: .center)
//        .font(.system(size: 17, weight: .light))
//    }
//}

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
