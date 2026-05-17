import AgencyRuntime
import Foundation
import SwiftUI


@Observable final class Editor: Frame {
    var panel: Panel = .processes
    var position: CGFloat = 220
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []

    enum Panel: Model {
        case processes

        var label: String {
            switch self {
            case .processes: ""
            }
        }

        var image: String {
            switch self {
            case .processes: ""
            }
        }
    }

    static func closures(_ agency: AgencyModel) -> Controls { return ProcessMapper.closures(agency) }
    static func params(_ agency: AgencyModel) -> Params { return ProcessMapper.params(agency) }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        Constructor.build(
            agency.studio.console,
            Console.params(agency),
            Console.closures(agency)
        )
    }
}

//ExecutionSurfaceStyle {
//   static let blockCornerRadius: CGFloat = 10
//   static let focusedColor = Color.accentColor
//   static let categoryColor = Color.secondary
//}

enum ExecutionBlockKind: String, CaseIterable, Identifiable {
   case paragraph = "Paragraph"
   case task = "Task"
   case tool = "Tool call"
   case service = "Service"
   case file = "File"
   case link = "Link"
   case sheet = "Sheet"

   var id: String { rawValue }

   var icon: String {
       switch self {
       case .paragraph: "text.alignleft"
       case .task: "checkmark.square"
       case .tool: "wrench.and.screwdriver"
       case .service: "powerplug"
       case .file: "doc"
       case .link: "link"
       case .sheet: "doc.text"
       }
   }

   var tint: Color { ExecutionSurfaceStyle.categoryColor }
}

enum ExecutionStatusTone {
   case ready
   case attention
   case failed
   case neutral

   var color: Color {
       switch self {
       case .ready: .green
       case .attention: ExecutionSurfaceStyle.focusedColor
       case .failed: .red
       case .neutral: .secondary
       }
   }

   var background: Color {
       switch self {
       case .ready: .green.opacity(0.14)
       case .attention: ExecutionSurfaceStyle.focusedColor.opacity(0.16)
       case .failed: .red.opacity(0.14)
       case .neutral: .secondary.opacity(0.12)
       }
   }
}

enum ExecutionSurfaceMode: String, CaseIterable, Identifiable {
   case write = "Write"
   case run = "Run"

   var id: String { rawValue }
}

struct ExecutionBlock: Identifiable {
   let id = UUID()
   let kind: ExecutionBlockKind
   let title: String
   var subtitle: String?
   var detail: String?
   var status: String?
   var tokens: [String] = []

   var statusTone: ExecutionStatusTone {
       guard let status else { return .neutral }
       let normalized = status.lowercased()

       if normalized.contains("not connected")
           || normalized.contains("needs auth")
           || normalized.contains("failed")
           || normalized.contains("error") {
           return .failed
       }

       if normalized.contains("connected")
           || normalized.contains("ready")
           || normalized.contains("runnable")
           || normalized.contains("done") {
           return .ready
       }

       if normalized.contains("draft")
           || normalized.contains("progress")
           || normalized.contains("attention") {
           return .attention
       }

       return .neutral
   }
}

struct ExecutionLibraryItem: Identifiable {
   let id = UUID()
   let kind: ExecutionBlockKind
   let title: String
   let subtitle: String
}

enum ExecutionSurfaceMockData {
   static let blocks: [ExecutionBlock] = [
       ExecutionBlock(
           kind: .paragraph,
           title: "Customer research brief",
           detail: "Collect the current notes, call the research tools, then turn the raw findings into a short brief that can be reviewed in this same sheet."
       ),
       ExecutionBlock(
           kind: .service,
           title: "OpenAI",
           subtitle: "account@email",
           status: "Connected",
           tokens: ["responses", "embeddings", "files"]
       ),
       ExecutionBlock(
           kind: .service,
           title: "GitHub",
           subtitle: "kaechle/agency",
           status: "Needs auth",
           tokens: ["issues", "pull requests"]
       ),
       ExecutionBlock(
           kind: .task,
           title: "Summarize open design issues",
           subtitle: "Agent or human can complete",
           status: "Ready"
       ),
       ExecutionBlock(
           kind: .tool,
           title: "Search repository",
           subtitle: "query",
           detail: "ExecutionSurface NavigationSplitView inspector",
           status: "Draft",
           tokens: ["rg", "Sources/Agency"]
       ),
       ExecutionBlock(
           kind: .link,
           title: "Shortcuts action library",
           subtitle: "https://support.apple.com/guide/shortcuts",
           status: "Open"
       ),
       ExecutionBlock(
           kind: .paragraph,
           title: "Notes",
           detail: "The document stays readable as prose, but capability blocks can expand into executable controls when the user focuses them."
       )
   ]

   static let librarySections: [(String, [ExecutionLibraryItem])] = [
       (
           "Runtime",
           [
               ExecutionLibraryItem(kind: .task, title: "Task", subtitle: "todo for agent or user"),
               ExecutionLibraryItem(kind: .tool, title: "Tool call", subtitle: "invoke a function"),
               ExecutionLibraryItem(kind: .service, title: "Service", subtitle: "third-party connection"),
               ExecutionLibraryItem(kind: .file, title: "File", subtitle: "attach a resource"),
               ExecutionLibraryItem(kind: .link, title: "Link", subtitle: "external reference"),
               ExecutionLibraryItem(kind: .sheet, title: "Sheet", subtitle: "nested document surface")
           ]
       ),
       (
           "Actions",
           [
               ExecutionLibraryItem(kind: .tool, title: "Ask for input", subtitle: "pause and collect text"),
               ExecutionLibraryItem(kind: .tool, title: "Choose from menu", subtitle: "branch from choices"),
               ExecutionLibraryItem(kind: .tool, title: "Run shell script", subtitle: "execute a command"),
               ExecutionLibraryItem(kind: .tool, title: "Search files", subtitle: "find local context"),
               ExecutionLibraryItem(kind: .tool, title: "Summarize", subtitle: "compress selected blocks")
           ]
       ),
       (
           "Services",
           [
               ExecutionLibraryItem(kind: .service, title: "OpenAI", subtitle: "models and files"),
               ExecutionLibraryItem(kind: .service, title: "GitHub", subtitle: "issues and pull requests"),
               ExecutionLibraryItem(kind: .service, title: "Slack", subtitle: "messages and channels"),
               ExecutionLibraryItem(kind: .service, title: "Google Drive", subtitle: "docs and folders")
           ]
       )
   ]
}

struct ExecutionSurface: View {
   @State private var selectedBlockID = ExecutionSurfaceMockData.blocks[4].id
   @State private var inspectorPresented = true
   @State private var searchText = ""
   @State private var mode: ExecutionSurfaceMode = .write

   private var selectedBlock: ExecutionBlock {
       ExecutionSurfaceMockData.blocks.first { $0.id == selectedBlockID } ?? ExecutionSurfaceMockData.blocks[0]
   }

   var body: some View {
       NavigationSplitView {
           ExecutionOutlineSidebar(
               blocks: ExecutionSurfaceMockData.blocks,
               selectedBlockID: selectedBlockID
           ) { blockID in
               selectedBlockID = blockID
           }
           .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 310)
       } detail: {
           ExecutionDocumentSurface(
               blocks: ExecutionSurfaceMockData.blocks,
               selectedBlockID: selectedBlockID,
               mode: mode
           ) { blockID in
               selectedBlockID = blockID
           }
           .toolbar(removing: .title)
           .toolbar {
               ToolbarItem(placement: .navigation) {
                   HStack(spacing: 8) {
                       Image(systemName: "terminal")
                           .foregroundStyle(.secondary)
                       Text("Composer")
                           .font(.headline)
                   }
               }

               ToolbarItem(placement: .principal) {
                   Picker("Mode", selection: Binding(get: { mode }, set: { mode = $0 })) {
                       ForEach(ExecutionSurfaceMode.allCases) { mode in
                           Text(mode.rawValue).tag(mode)
                       }
                   }
                   .pickerStyle(.segmented)
                   .labelsHidden()
                   .frame(width: 140)
               }

               ToolbarItemGroup {
                   Button { } label: {
                       Image(systemName: "square.and.arrow.up")
                   }
                   .help("Share")

                   Button { } label: {
                       Image(systemName: "play.fill")
                   }
                   .help("Run focused block")

                   Button {
                       inspectorPresented.toggle()
                   } label: {
                       Image(systemName: "sidebar.right")
                   }
                   .help("Toggle library")
               }
           }
       }
       .inspector(isPresented: $inspectorPresented) {
           ExecutionLibraryInspector(
               searchText: $searchText,
               selectedBlock: selectedBlock
           )
           .inspectorColumnWidth(min: 280, ideal: 330, max: 420)
           .toolbar {
               ToolbarItemGroup {
                   Button { } label: {
                       Image(systemName: "shippingbox")
                   }
                   .help("Action Library")

                   Button { } label: {
                       Image(systemName: "info.circle")
                   }
                   .help("Block Info")
               }
           }
       }
   }
}

struct ExecutionOutlineSidebar: View {
   let blocks: [ExecutionBlock]
   let selectedBlockID: UUID?
   let select: (UUID) -> Void

   var body: some View {
       List {
           Section("Sheet") {
               Label("Customer research brief", systemImage: "doc.text")
                   .font(.headline)
           }

           Section("Blocks") {
               ForEach(blocks) { block in
                   Button {
                       select(block.id)
                   } label: {
                       HStack(spacing: 10) {
                           Image(systemName: block.kind.icon)
                               .foregroundStyle(ExecutionSurfaceStyle.categoryColor)
                               .frame(width: 16)

                           VStack(alignment: .leading, spacing: 2) {
                               Text(block.title)
                                   .lineLimit(1)

                               HStack(spacing: 5) {
                                   if block.status != nil {
                                       Image(systemName: "circle.fill")
                                           .font(.system(size: 5))
                                           .foregroundStyle(block.statusTone.color)
                                   }

                                   Text(block.kind.rawValue.lowercased())
                                       .font(.caption)
                                       .foregroundStyle(.secondary)

                                   if let status = block.status {
                                       Text("· \(status.lowercased())")
                                           .font(.caption)
                                           .foregroundStyle(.secondary)
                                   }
                               }
                           }

                           Spacer(minLength: 4)
                       }
                       .padding(.horizontal, 8)
                       .padding(.vertical, 6)
                       .background(selectedBlockID == block.id ? ExecutionSurfaceStyle.focusedColor.opacity(0.14) : Color.clear)
                       .clipShape(.rect(cornerRadius: 7))
                   }
                   .buttonStyle(.plain)
               }
           }
       }
       .listStyle(.sidebar)
   }
}

struct ExecutionDocumentSurface: View {
   let blocks: [ExecutionBlock]
   let selectedBlockID: UUID?
   let mode: ExecutionSurfaceMode
   let select: (UUID) -> Void

   var body: some View {
       ScrollView {
           VStack(alignment: .leading, spacing: 18) {
               ExecutionDocumentHeader(mode: mode)

               ForEach(blocks) { block in
                   ExecutionBlockView(
                       block: block,
                       selected: selectedBlockID == block.id,
                       compact: block.kind == .paragraph
                   )
                   .onTapGesture {
                       select(block.id)
                   }
               }

               Button { } label: {
                   Label("Add block", systemImage: "plus")
                       .font(.callout)
                       .frame(maxWidth: .infinity)
                       .padding(.vertical, 12)
               }
               .buttonStyle(.plain)
               .foregroundStyle(.secondary)
               .background(.quaternary.opacity(0.18))
               .overlay {
                   RoundedRectangle(cornerRadius: ExecutionSurfaceStyle.blockCornerRadius)
                       .stroke(.separator.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
               }
               .clipShape(.rect(cornerRadius: ExecutionSurfaceStyle.blockCornerRadius))
               .padding(.top, 8)
           }
           .padding(.horizontal, 48)
           .padding(.vertical, 38)
           .frame(maxWidth: 820)
           .frame(maxWidth: .infinity)
       }
       .background(Color(nsColor: .textBackgroundColor).opacity(0.06))
   }
}

struct ExecutionDocumentHeader: View {
   let mode: ExecutionSurfaceMode

   var body: some View {
       VStack(alignment: .leading, spacing: 9) {
           HStack(alignment: .firstTextBaseline) {
               VStack(alignment: .leading, spacing: 6) {
                   Text("Customer research brief")
                       .font(.largeTitle.weight(.semibold))
               }

               Spacer()

               Label(mode == .write ? "Draft" : "Runnable", systemImage: mode == .write ? "pencil" : "play.fill")
                   .font(.callout.weight(.medium))
                   .foregroundStyle(mode == .write ? Color.secondary : ExecutionStatusTone.ready.color)
           }

           HStack(spacing: 6) {
               ExecutionToken(text: "Sheet")
               ExecutionToken(text: "Agent shared")
               ExecutionToken(text: "Last edited 2m ago")
           }
       }
       .padding(.bottom, 4)
   }
}

struct ExecutionBlockView: View {
   let block: ExecutionBlock
   let selected: Bool
   var compact: Bool = false

   var body: some View {
       if block.kind == .paragraph {
           ExecutionMarkdownBlock(block: block, selected: selected)
       } else {
           VStack(spacing: 0) {
               HStack(spacing: 8) {
                   Image(systemName: "circle.fill")
                       .font(.system(size: 7))
                       .foregroundStyle(block.statusTone.color)

                   Label(block.kind.rawValue.uppercased(), systemImage: block.kind.icon)
                       .font(.caption.weight(.medium))
                       .foregroundStyle(ExecutionSurfaceStyle.categoryColor)
                       .labelStyle(.titleAndIcon)

                   Spacer()

                   if let status = block.status {
                       ExecutionStatusBadge(status: status, tone: block.statusTone)
                   }
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 8)
               .background(.quaternary.opacity(0.16))

               VStack(alignment: .leading, spacing: 10) {
                   HStack(alignment: .center, spacing: 12) {
                       Image(systemName: block.kind.icon)
                           .font(.system(size: 18, weight: .medium))
                           .foregroundStyle(ExecutionSurfaceStyle.categoryColor)
                           .frame(width: 34, height: 34)
                           .background(.quaternary.opacity(0.26))
                           .clipShape(.rect(cornerRadius: 8))

                       VStack(alignment: .leading, spacing: 3) {
                           Text(block.title)
                               .font(.title3.weight(.semibold))
                               .lineLimit(1)

                           if let subtitle = block.subtitle {
                               Text(subtitle)
                                   .font(.callout)
                                   .foregroundStyle(.secondary)
                                   .lineLimit(1)
                           }
                       }

                       Spacer()

                       if block.kind == .tool {
                           Button("Configure") { }
                               .controlSize(.small)
                       } else if block.kind == .service {
                           Button("Connect") { }
                               .controlSize(.small)
                       } else if block.kind == .file || block.kind == .link {
                           Button { } label: {
                               Image(systemName: "arrow.up.right")
                           }
                           .buttonStyle(.borderless)
                       }
                   }

                   if let detail = block.detail {
                       Text(detail)
                           .font(block.kind == .tool ? .system(.callout, design: .monospaced) : .callout)
                           .foregroundStyle(.secondary)
                           .lineLimit(3)
                   }

                   if !block.tokens.isEmpty {
                       HStack(spacing: 6) {
                           ForEach(block.tokens, id: \.self) { token in
                               ExecutionToken(text: token)
                           }
                       }
                   }
               }
               .padding(14)
           }
           .background(Color(nsColor: .controlBackgroundColor))
           .overlay {
               RoundedRectangle(cornerRadius: ExecutionSurfaceStyle.blockCornerRadius)
                   .stroke(
                       selected ? ExecutionSurfaceStyle.focusedColor.opacity(0.85) : Color(nsColor: .separatorColor).opacity(0.55),
                       lineWidth: selected ? 1.5 : 1
                   )
           }
           .clipShape(.rect(cornerRadius: ExecutionSurfaceStyle.blockCornerRadius))
           .shadow(color: .black.opacity(selected ? 0.12 : 0.04), radius: selected ? 10 : 3, y: selected ? 4 : 1)
       }
   }
}

struct ExecutionStatusBadge: View {
   let status: String
   let tone: ExecutionStatusTone

   var body: some View {
       HStack(spacing: 5) {
           Image(systemName: "circle.fill")
               .font(.system(size: 6))
               .foregroundStyle(tone.color)

           Text(status.uppercased())
               .font(.caption2.weight(.semibold))
               .foregroundStyle(tone.color)
       }
       .padding(.horizontal, 7)
       .padding(.vertical, 3)
       .background(tone.background)
       .clipShape(.capsule)
   }
}

struct ExecutionMarkdownBlock: View {
   let block: ExecutionBlock
   let selected: Bool

   var body: some View {
       VStack(alignment: .leading, spacing: 8) {
           if block.title != "Notes" && block.title != "Customer research brief" {
               Text(block.title)
                   .font(.title2.weight(.semibold))
           }

           if let detail = block.detail {
               Text(detail)
                   .font(.body)
                   .foregroundStyle(.primary.opacity(0.86))
                   .lineSpacing(4)
           }
       }
       .padding(.horizontal, 10)
       .padding(.vertical, 10)
       .frame(maxWidth: .infinity, alignment: .leading)
       .background(selected ? ExecutionSurfaceStyle.focusedColor.opacity(0.08) : Color.clear)
       .clipShape(.rect(cornerRadius: ExecutionSurfaceStyle.blockCornerRadius))
   }
}

struct ExecutionToken: View {
   let text: String

   var body: some View {
       Text(text)
           .font(.caption.weight(.medium))
           .foregroundStyle(.secondary)
           .padding(.horizontal, 8)
           .padding(.vertical, 4)
           .background(.quaternary.opacity(0.28))
           .clipShape(.capsule)
   }
}

struct ExecutionLibraryInspector: View {
   @Binding var searchText: String
   let selectedBlock: ExecutionBlock

   var body: some View {
       VStack(spacing: 0) {
           VStack(alignment: .leading, spacing: 14) {
               TextField("Search Actions", text: $searchText)
                   .textFieldStyle(.roundedBorder)

               Text("Drag into the document, or click to append. Blocks stay readable until they need to expose controls.")
                   .font(.callout)
                   .foregroundStyle(.secondary)
                   .fixedSize(horizontal: false, vertical: true)
           }
           .padding(16)

           List {
               Section("Focused Block") {
                   HStack(spacing: 10) {
                       Image(systemName: selectedBlock.kind.icon)
                           .foregroundStyle(ExecutionSurfaceStyle.categoryColor)
                           .frame(width: 18)

                       VStack(alignment: .leading, spacing: 2) {
                           Text(selectedBlock.title)
                               .lineLimit(1)
                           Text(selectedBlock.kind.rawValue)
                               .font(.caption)
                               .foregroundStyle(.secondary)
                       }

                       Spacer()

                       if let status = selectedBlock.status {
                           ExecutionStatusBadge(status: status, tone: selectedBlock.statusTone)
                       }
                   }
               }

               ForEach(filteredSections, id: \.0) { section, items in
                   Section(section) {
                       ForEach(items) { item in
                           ExecutionLibraryRow(item: item)
                       }
                   }
               }

               Section("Shortcuts") {
                   ShortcutHint(keys: "⌘↩", label: "Run focused block")
                   ShortcutHint(keys: "⌘/", label: "Insert block")
                   ShortcutHint(keys: "⌘⇧I", label: "Toggle inspector")
               }
           }
           .listStyle(.sidebar)
       }
   }

   private var filteredSections: [(String, [ExecutionLibraryItem])] {
       guard !searchText.isEmpty else { return ExecutionSurfaceMockData.librarySections }

       return ExecutionSurfaceMockData.librarySections.compactMap { section, items in
           let filtered = items.filter {
               $0.title.localizedCaseInsensitiveContains(searchText)
               || $0.subtitle.localizedCaseInsensitiveContains(searchText)
               || $0.kind.rawValue.localizedCaseInsensitiveContains(searchText)
           }

           return filtered.isEmpty ? nil : (section, filtered)
       }
   }
}

struct ExecutionLibraryRow: View {
   let item: ExecutionLibraryItem

   var body: some View {
       Button { } label: {
           HStack(spacing: 10) {
               Image(systemName: item.kind.icon)
                   .foregroundStyle(item.kind.tint)
                   .frame(width: 18)

               VStack(alignment: .leading, spacing: 2) {
                   Text(item.title)
                       .lineLimit(1)

                   Text(item.subtitle)
                       .font(.caption)
                       .foregroundStyle(.secondary)
                       .lineLimit(1)
               }

               Spacer(minLength: 0)
           }
       }
       .buttonStyle(.plain)
   }
}

struct ShortcutHint: View {
   let keys: String
   let label: String

   var body: some View {
       HStack {
           Text(keys)
               .font(.system(.caption, design: .monospaced))
               .foregroundStyle(.secondary)
               .frame(width: 42, alignment: .leading)

           Text(label)
               .font(.callout)
               .foregroundStyle(.secondary)
       }
   }
}
