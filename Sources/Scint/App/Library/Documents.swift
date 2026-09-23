import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct Documents: Surface {
    var panel: any Panel
    var model: any Model

    var library: Reference { model.session.library }

    var documents: [Reference] { Self.documents(under: [library]) }

    static func documents(under roots: [Reference]) -> [Reference] {
        func spaces(in ref: Reference) -> [Reference] { [ref] + (Space.with(ref, { Array($0.spaces) }) ?? []).flatMap { spaces(in: $0) } }
        return roots.flatMap { spaces(in: $0) }
            .flatMap { Space.with($0, { $0.documents }) ?? [] }
            .filter { !$0.descriptor.tags.contains("input") }
            .reduce(into: [Reference]()) { if !$0.contains($1) { $0.append($1) } }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Style.Spacing.entry)], spacing: Style.Spacing.entry) {
                if !documents.isEmpty {
                    ForEach(documents) { document in
                        DocumentCard(
                            ref: document,
                            model: model,
                            selected: model.session.selection.selected(document),
                            isHovered: false
                        )
                        .onTapGesture { model.select(document) }
                        .onTapGesture(count: 2) { model.open(document) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, Style.Spacing.section)
        }
        .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Style.Background.canvas)
    }
}
