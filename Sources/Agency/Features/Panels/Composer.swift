//import AgencyRuntime
//import SwiftUI
//import Foundation
//
//
//@Observable final class Composer: Panel {
//    var model: Model = .composer
//    var layout: Layout = .list
//    var presented: Bool = false
//    var position: CGFloat = 0
//    var expanded: Set<AnyHashable> = []
//
//    enum Model: String, CaseIterable { case composer }
//
//    func closures(_ agency: AgencyModel) -> Closures { ComposerMap.closures(agency, self) }
//    func params(_ agency: AgencyModel) -> Params { ComposerMap.params(agency, self) }
//
//    @MainActor func build(_ agency: AgencyModel) -> some View {
//        func sheet(for workspace: Reference) -> Reference {
//            guard let closure = Workspace.with(workspace, { $0.closure }) else { return Sheet.new("Workspace Composer", owner: workspace) }
//            if let sheet = Closure.with(closure, { $0.sheets.first }) ?? nil { return sheet }
//            let sheet = Sheet.new("Workspace Composer", owner: closure)
//            Closure.update(closure) { if !$0.sheets.contains(sheet) { $0.sheets.append(sheet) } }
//            return sheet
//        }
//
//        let sheet = sheet(for: agency.session.workspace)
//
//        return ScrollView {
//            Editor(ref: sheet)
//                .frame(maxWidth: .infinity, alignment: .topLeading)
//                .padding(32)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
