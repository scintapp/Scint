import SwiftUI
import ScintComponents

//
//struct StackedTaskRow: View {
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack(alignment: .center) {
//                Image(systemName: "app")
//                    .font(.system(size: 18))
//                    .frame(alignment: .leading)
//
//                Text("Review command runner states")
//                    .frame(alignment: .leading)
//                    .font(.title3.weight(.medium))
//                    .foregroundStyle(.primary)
//                    .padding(.bottom, 4)
//                    .padding(.leading, 4)
//
//                Spacer()
//                    Button { } label: {
//                        Label("Engineering", systemImage: "app")
//                            .font(.caption2)
//                    }
//                }
//                .frame(alignment: .trailing)
//
//
//            VStack(alignment: .leading) {
//                Text("Today, 9:00 AM")
//                    .foregroundStyle(.secondary)
//                    .font(.subheadline)
////                Text("Check for failed runs and summarize flaky tests.")
////                    .foregroundStyle(.secondary)
////                    .font(.subheadline)
//            }
//            .padding(.leading, 32)
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 12)
//        .frame(maxWidth: 240, maxHeight: 130, alignment: .top)
//        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
//    }
//}
//
//struct TaskColumn: View {
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            VStack(alignment: .leading, spacing: 4) {
////                SectionHeader()
//                Text("Active work for this week.")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//            }
//            VStack(spacing: 8) {
//                ForEach(0..<4) { _ in StackedTaskRow() }
//            }
//            Spacer(minLength: 0)
//        }
//        .frame(maxWidth: .infinity, alignment: .topLeading)
//        .padding(.horizontal, 14)
//        .overlay(alignment: .trailing) { Divider() }
//    }
//}
//
//struct TaskColumns: View {
//    var body: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 12) {
//                Button { } label: {
//                    Image(systemName: "rectangle.compress.vertical")
//                        .frame(width: 30, height: 30)
//                }
//                .buttonStyle(.plain)
//            }
//            .padding(.trailing, 24)
//
//            HStack(alignment: .top, spacing: 0) {
//                ForEach(0..<3) { _ in TaskColumn() }
//            }
//            .padding(.top, 8)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .background(.background)
//    }
//}
//
//#Preview {
//    TaskColumns()
//        .preferredColorScheme(.dark)
//        .frame(width: 1440, height: 900)
//}
