import SwiftUI
import AgencyRuntime



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

struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var space: Reference { agency.session.space }
    private var boundary: Reference? { agency.session.boundary }
    private var sheet: Reference? { agency.session.sheet }

    var body: some View {
        ControlGroup {
            Button { agency.backward() } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.canGoBack)
            Button { agency.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.canGoForward)
        }
        .controlGroupStyle(.navigation)
        .glassEffect(.regular.tint(.black.opacity(0.05)))
    }
}

struct ActionRow: View {
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

struct SpaceRow: View {
    @Environment(AgencyModel.self) var agency
    @State private var isHovered = false
    let ref: Reference
    let selected: Bool

    private var name: String { Workspace.with(ref) { $0.name } ?? "Space" }

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

struct SpacesControls: View {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool
    @Binding var text: String

    private var space: Reference { agency.session.space }
    private var spaces: [Reference] { Runtime.shared.spaces }
    private func select(_ ref: Reference) { }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Filter(text: $text)
                .padding(.vertical, 6)

            VStack(spacing: 2) {
                SpaceRow(ref: space, selected: true)
                    .onTapGesture { select(space) }

                ForEach(spaces) { space in
                    SpaceRow(ref: space, selected: false)
                        .onTapGesture { select(space) }
                }
            }
            .padding(.horizontal, 8)

            Divider()
                .padding(.horizontal, 6)
                .padding(.vertical, 12)

            VStack(spacing: 2) {
                ActionRow(title: "New Space...") { }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(width: 280)
        .padding(2)
    }
}

struct RuntimeControls: View {
    @Environment(AgencyModel.self) var agency
    @State private var presented = false
    @State private var text = ""

    private var space: Reference { agency.session.space }
    private var boundary: Reference? { agency.session.boundary }
    private var sheet: Reference? { agency.session.sheet }

    private var selection: Reference {
        if let sheet { return sheet }
        else if let boundary { return boundary }
        return space
    }

    var body: some View {
        ControlGroup {
            HStack {
                Button { presented.toggle() } label: {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 11))
                        .frame(width: 16, height: 16, alignment: .center)
                }
                .frame(width: 72, alignment: .leading)
                .popover(isPresented: $presented) {
                    SpacesControls(presented: $presented, text: $text)
                }

                Spacer()

                ControlGroup {
                    switch selection.type {
                    case is Sheet.Type:
                        return Button { } label: {
                            Text(Sheet.with(selection, { $0.name }) ?? "")
                                .font(.system(size: 11, weight: .medium))
                        }
                    case is Space.Type:
                        return Button { } label: {
                            Text(Space.with(selection, { $0.name }) ?? "")
                                .font(.system(size: 11, weight: .medium))
                        }
                    case is Workspace.Type:
                        return Button { } label: {
                            Text(Workspace.with(selection, { $0.name }) ?? "")
                                .font(.system(size: 11, weight: .medium))
                        }
                    default:
                        return  Button { } label: {
                            Text("")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }

                Spacer()

                ControlGroup {
                    Button { } label: { Image(systemName: "stop.fill") }
                        .disabled(true)
                        .font(.system(size: 11))
                        .help("Stop the currently running boundary")

                    Button { } label: { Image(systemName: "play.fill") }
                        .font(.system(size: 11))
                        .help("Start the selected boundary")
                }
                .frame(maxWidth: 72, alignment: .trailing)
            }
            .frame(minWidth: 380, maxWidth: 540)
        }
        .glassEffect(.regular.tint(.black.opacity(0.05)))
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

