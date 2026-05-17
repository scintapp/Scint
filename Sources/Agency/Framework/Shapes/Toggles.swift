import AgencyRuntime
import AppKit
import SwiftUI


struct LibraryToggle: View {
    @State var isPresented: Bool = false

    public var body: some View {
        Button {  } label: {
            Image(systemName: "building.columns")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .help("Open the library panel.")
        }
        .labelsHidden()
    }
}

struct NavigatorToggle: View {
    @Binding var presented: Bool
    public init(presented: Binding<Bool>) { _presented = presented }

    public var body: some View {
        HStack(spacing: 0) {
            if presented {
                Button {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                    presented.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                }
            } else {
                Button {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                    presented.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
    }
}

struct InspectorToggle: View {
    @Binding var presented: Bool
    public init(presented: Binding<Bool>) { _presented = presented }

    public var body: some View {
        HStack(spacing: 0) {
            if presented {
                Button { presented.toggle() } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                }
            } else {
                Button { presented.toggle() } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(minHeight: 36, idealHeight: 36, maxHeight: 36)
    }
}

struct SidebarModeToggle: View {
    @Environment(AgencyModel.self) var agency

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

    @ViewBuilder var body: some View {}
}
