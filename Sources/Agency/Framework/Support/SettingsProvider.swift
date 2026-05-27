//import AgencyRuntime
//import Foundation
//import SwiftUI
//
//
//struct SettingsActionRow: View {
//    @State private var isHovered = false
//    let title: String
//    var action: () -> Void = {}
//
//    var body: some View {
//        HStack(alignment: .center) {
//            Text(title)
//                .font(.system(size: 13))
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.horizontal, 10)
//        .padding(.vertical, 6)
//        .contentShape(RoundedRectangle(cornerRadius: 10))
//        .background {
//            RoundedRectangle(cornerRadius: 10)
//                .fill(isHovered ? Color.accentColor.opacity(0.4) : Color.clear)
//        }
//        .onHover { isHovered = $0 }
//        .onTapGesture { action() }
//    }
//}
//
//struct SettingsDetailRow: View {
//    @Environment(AgencyModel.self) var agency
//    @State private var isHovered = false
//    let ref: Reference
//    let selected: Bool
//
//    private var name: String {
//        Workspace.with(ref) { $0.name } ?? Space.with(ref) { $0.name } ?? "Space"
//    }
//
//    var body: some View {
//        HStack(alignment: .center) {
//            Text(name)
//                .font(.system(size: 13, weight: .medium))
//        }
//        .frame(height: 24)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.horizontal, 10)
//        .padding(.vertical, 6)
//        .contentShape(RoundedRectangle(cornerRadius: 10))
//        .background {
//            RoundedRectangle(cornerRadius: 10)
//                .fill(isHovered ? Color.accentColor.opacity(0.4) : Color.clear)
//        }
//        .onHover { isHovered = $0 }
//    }
//}
//
//
//
//struct DomainSettings: View {
//    @Environment(AgencyModel.self) var agency
//    let ref: Reference
//    var presented: Bool
//    var surface: Surface
//
//    enum Domain: CaseIterable { case component, interface, structure }
//    enum Surface: CaseIterable { case data, services }
//
//    var body: some View {
//
//    }
//}
//
//struct DomainSurface: View {
//    var body: some View {
//        TabView(selection: $tab) {
//            VStack(alignment: .leading, spacing: 0) {
//                Filter(text: $text)
//                    .padding(.vertical, 6)
//
//                VStack(spacing: 2) {
//                    ForEach(spaces) { space in
//                        SpaceRow(ref: space, selected: space == agency.session.workspace)
//                            .onTapGesture { select(space) }
//                    }
//                }
//                .padding(.horizontal, 8)
//
//                Divider()
//                    .padding(.horizontal, 6)
//                    .padding(.vertical, 12)
//
//                VStack(spacing: 2) {
//                    SpaceActionRow(title: "New Space...") { }
//                }
//                .padding(.horizontal, 8)
//                .padding(.bottom, 6)
//            }
//            .tabItem { Label("Workspaces", systemImage: "cube.transparent") }
//            .tag(WorkspaceSheetTab.workspaces)
//        }
//        .frame(width: 220, height: 240)
//    }
//}
//
//struct WorkspaceControls: View {
//    @Environment(AgencyModel.self) var agency
//    @Binding var presented: Bool
//    @Binding var text: String
//    @Binding var tab: WorkspaceSheetTab
//
//    private var spaces: [Reference] { Runtime.shared.spaces }
//
//    private func select(_ ref: Reference) {
//        agency.select(ref)
//        presented = false
//    }
//
//    var body: some View {
//        TabView(selection: $tab) {
//            VStack(alignment: .leading, spacing: 0) {
//                Filter(text: $text)
//                    .padding(.vertical, 6)
//
//                VStack(spacing: 2) {
//                    ForEach(spaces) { space in
//                        SpaceRow(ref: space, selected: space == agency.session.workspace)
//                            .onTapGesture { select(space) }
//                    }
//                }
//                .padding(.horizontal, 8)
//
//                Divider()
//                    .padding(.horizontal, 6)
//                    .padding(.vertical, 12)
//
//                VStack(spacing: 2) {
//                    SpaceActionRow(title: "New Space...") { }
//                }
//                .padding(.horizontal, 8)
//                .padding(.bottom, 6)
//            }
//            .tabItem { Label("Workspaces", systemImage: "cube.transparent") }
//            .tag(WorkspaceSheetTab.workspaces)
//
//            //            WorkspaceDefaultsControls(services: services, controls: controls, artifacts: artifacts)
//            //                .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }
//            //                .tag(WorkspaceSheetTab.defaults)
//        }
//        .frame(width: 220, height: 240)
//    }
//}
//
//struct RuntimeControls: View {
//    @Environment(AgencyModel.self) var agency
//    @State private var presented = false
//    @State private var text = ""
//    @State private var tab: WorkspaceSheetTab = .workspaces
//    @State private var service: Reference?
//
//    private var services: [Reference] { Workspace.with(agency.session.workspace, { $0.services }) ?? [] }
//
//    private func start() {
//        guard let space = agency.session.space, let service, let closure = Space.with(space, { $0.closure }) else { return }
//        do { try Runtime.shared.process(space, service: service, closure: closure) }
//        catch { print("Process initialization failed: \(error)") }
//    }
//
//    private func stop() { }
//
//    var body: some View {
//        ControlGroup {
//            HStack {
//                Group {
//                    Button { workspace.toggle() } label: {
//                        Image(systemName: "cube.transparent")
//                        Text(Workspace.with(agency.session.workspace, { $0.name }) ?? "")
//                        Image(systemName: "chevron.compact.forward")
//                    }
//                    .help("Manage Workspace")
//                    .popover(isPresented: $presented) {
//                        WorkspaceControls(presented: $presented, text: $text, tab: $tab)
//                    }
//                }
//                .font(.system(size: 10))
//
//                Group {
//                    Button { space.toggle() } label: {
//                        Image(systemName: "app")
//                        agency.session.space != nil ? Text(Space.with(agency.session.space!, { $0.name }) ?? "") : Text("")
//                    }
//                    .help("Manage Space")
//                    .popover(isPresented: $presented) {
//                        SpaceControls(presented: $presented, text: $text, tab: $tab)
//                    }
//                }
//                .font(.system(size: 10))
//
//                Spacer()
//
//                ControlGroup {
//                    Button { stop() } label: { Image(systemName: "stop.fill") }
//                        .disabled(true)
//                        .font(.system(size: 11))
//                        .help("Stop a running process on this space")
//
//                    Button { start() } label: { Image(systemName: "play.fill") }
//                        .disabled(agency.session.space == nil || service == nil)
//                        .font(.system(size: 11))
//                        .help("Start a process from this space")
//                }
//                .controlGroupStyle(.navigation)
//            }
//        }
//        .frame(minWidth: 480, maxWidth: 640, alignment: .center)
//        .glassEffect(.regular.tint(.black.opacity(0.05)))
//    }
//}
//
//
//@Observable final class SettingsProvider {
//    var model: Model = .general
//    var mappers: [String : any Mapper] = [:]
//
//    enum Model: String, CaseIterable {
//        case components
//        case context
//        case interfaces
//        case structures
//    }
//
//    func build(_ agency: AgencyModel) -> some View {
//        EmptyView()
//    }
//}
//
//struct SettingsSidebar: View {
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            List {
//                HStack(spacing: 4) {
//                }
//            }
//        }
//        .toolbar(removing: .sidebarToggle)
//    }
//}
//
//struct SettingsContent: View {
//    var body: some View {
//        EmptyView()
//    }
//}
//
