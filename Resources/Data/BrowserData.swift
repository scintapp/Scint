//import SwiftUI
//
//
//enum BrowserMockData {
//    static let favorites: [BrowserSidebarItem] = [
//        BrowserSidebarItem(name: "kaechle", icon: "house"),
//        BrowserSidebarItem(name: "Applications", icon: "app.badge"),
//        BrowserSidebarItem(name: "Desktop", icon: "rectangle", trailingSystemImage: "icloud"),
//        BrowserSidebarItem(name: "Documents", icon: "doc", trailingSystemImage: "icloud"),
//        BrowserSidebarItem(name: "Developer", icon: "hammer")
//    ]
//
//    static let locations: [BrowserSidebarItem] = [
//        BrowserSidebarItem(name: "Macintosh HD", icon: "internaldrive"),
//        BrowserSidebarItem(name: "Trash", icon: "trash")
//    ]
//
//    static let tags: [BrowserSidebarItem] = [
//        BrowserSidebarItem(name: "Composition", icon: "circle", tint: .pink),
//        BrowserSidebarItem(name: "Discovery", icon: "circle", tint: .orange)
//    ]
//
//    static let files: [BrowserMockItem] = [
//        BrowserMockItem(name: "Core", icon: "folder.fill", dateModified: "Yesterday at 20:39:58", size: "40 KB"),
//        BrowserMockItem(name: "Editor", icon: "folder.fill", dateModified: "Yesterday at 20:39:58", size: "12 KB"),
//        BrowserMockItem(name: "Models", icon: "folder.fill", dateModified: "Yesterday at 20:39:54", size: "6 KB"),
//        BrowserMockItem(name: "Views", icon: "folder.fill", dateModified: "Yesterday at 20:39:58", size: "21 KB")
//    ]
//
//    static let path: [BrowserMockItem] = [
//        BrowserMockItem(name: "Macintosh HD", icon: "internaldrive"),
//        BrowserMockItem(name: "Users", icon: "folder.fill"),
//        BrowserMockItem(name: "kaechle", icon: "folder.fill"),
//        BrowserMockItem(name: "Developer", icon: "folder.fill"),
//        BrowserMockItem(name: "Agency", icon: "folder.fill"),
//        BrowserMockItem(name: "Backup", icon: "folder.fill"),
//        BrowserMockItem(name: "Editor", icon: "folder.fill"),
//        BrowserMockItem(name: "Views", icon: "folder.fill")
//    ]
//}
//
//struct BrowserMockItem: Identifiable {
//    let id = UUID()
//    let name: String
//    let icon: String
//    var subtitle: String?
//    var tags: String = ""
//    var dateModified: String = "Yesterday at 20:39:58"
//    var size: String = "12 KB"
//}
//
//struct BrowserSidebarItem: Identifiable {
//    let id = UUID()
//    let name: String
//    let icon: String
//    var tint: Color = .secondary
//    var trailingSystemImage: String?
//}
