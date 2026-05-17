import SwiftUI
import AgencyRuntime



//struct PanelContent: View {
//    var index: Int
//    let onTap: (ItemParams) -> Void
//
//    var body: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 2) {
//                    if isEmpty {
//                        empty
//                    } else {
//                        content
//                    }
//                }
//                .padding(.horizontal, 8)
//                .onChange(of: index) {
//                    guard flatItems.indices.contains(index) else { return }
//                    proxy.scrollTo(flatItems[index].id, anchor: .center)
//                }
//            }
//        }
//    }
//
//    private var content: some View {
//        var index = 0
//        return ForEach(params.sections) { section in
//            sectionView(section, startIndex: runningIndexBefore(section))
//        }
//        .id(params.sections.map(\.id))
//    }
//
//    private func runningIndexBefore(_ section: ListParams) -> Int {
//        var count = 0
//        for s in params.sections {
//            if s.id == section.id { return count }
//            count += s.items.count
//        }
//        return count
//    }
//
//    @ViewBuilder
//    private func sectionView(_ section: ListParams, startIndex: Int) -> some View {
//        if section.header && !section.name.isEmpty {
//            Text(section.name)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 8)
//                .padding(.top, 12)
//                .padding(.bottom, 6)
//        }
//
//        ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, item in
//            let absolute = startIndex + offset
//            PanelRow(
//                item: item,
//                isSelected: absolute == index,
//                onTap: {
//                    index = absolute
//                    onTap(item)
//                }
//            )
//            .id(item.id)
//        }
//    }
//
//    private var empty: some View {
//        VStack {
//            Text("No results")
//                .font(.system(size: 13))
//                .foregroundStyle(.secondary)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 32)
//    }
//}
