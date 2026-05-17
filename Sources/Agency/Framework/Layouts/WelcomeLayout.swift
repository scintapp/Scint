import SwiftUI


struct RecentProject: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var path: String
    var iconSystemName: String = "doc.fill"
}

struct PanelActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.12 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct RecentRow: View {
    let project: RecentProject
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.iconSystemName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 1.0))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(project.path)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(selected ? Color.white.opacity(0.14) : Color.clear)
        )
    }
}

struct WelcomeScreen: View {
    @State private var selection: RecentProject.ID?
    var name: String = "Agency"
    var image: String?
    var version: String = "Beta 1.0"
    var recents: [RecentProject]
    var onClose: () -> Void = {}
    var onCreate: () -> Void = {}
    var onClone: () -> Void = {}
    var onOpen: () -> Void = {}
    var onSelect: (RecentProject) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            leftPane
                .frame(width: 480)
            Divider()
                .overlay(Color.black.opacity(0.4))
            rightPane
                .frame(minWidth: 280)
        }
        .frame(width: 800, height: 480)
        .background(.black.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .circular)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 40, y: 20)
        .onAppear { selection = recents.first?.id }
    }

    private var leftPane: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .padding(14)

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                appIcon
                    .frame(width: 132, height: 132)
                    .shadow(color: .blue.opacity(0.35), radius: 30, y: 4)

                Text(name)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text(version)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)

                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    PanelActionButton(
                        title: "New Project",
                        systemImage: "plus.app",
                        action: onCreate
                    )
                    PanelActionButton(
                        title: "Open Folder",
                        systemImage: "folder",
                        action: onOpen
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .background(.windowBackground)
    }

    @ViewBuilder private var appIcon: some View {
        if let name = image, let _ = NSImage(named: name) {
            Image(nsImage: NSImage(named: name)!)
                .resizable()
                .interpolation(.high)
        } else {
            RoundedRectangle(cornerRadius: 26, style: .circular)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.67, blue: 1.0),
                            Color(red: 0.06, green: 0.36, blue: 0.86)],
                        startPoint: .topLeading, endPoint: .bottom
                    )
                )
        }
    }

    private var rightPane: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(recents) { project in
                    RecentRow(
                        project: project,
                        selected: selection == project.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = project.id
                        onSelect(project)
                    }
                }
            }
            .padding(10)
        }
        .scrollContentBackground(.hidden)
    }
}
