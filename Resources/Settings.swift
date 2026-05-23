//import SwiftUI
//import Foundation
//
//
//@Observable final class Settings {
//    var mappers: [String : any Mapper] = [:]
//    var model: Model = .general
//
//    enum Model: String, CaseIterable {
//        case general
//        case accounts
//        case editing
//        case locations
//        case services
//        case advanced
//
//        var path: String {
//            switch self {
//            case .general: "General"
//            case .accounts: "Accounts"
//            case .editing: "Editing"
//            case .locations: "Locations"
//            case .services: "Services"
//            case .advanced: "Advanced"
//            }
//        }
//
//        var icon: String {
//            switch self {
//            case .general: "gear"
//            case .accounts: "person.crop.circle"
//            case .editing: "square.and.pencil"
//            case .locations: "square.and.arrow.down"
//            case .services: "externaldrive.connected.to.line.below"
//            case .advanced: "gearshape.2"
//            }
//        }
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
//                    ForEach(Settings.Model.allCases, id: \.self) { link in
//                        VStack {
//                            Image(systemName: link.icon)
//                            NavigationLink(destination: SettingsContent()) {
//                                Text(link.path)
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//                                    .tag(link.path)
//                            }
//                        }
//                    }
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
