//import Foundation
//
//
//extension Markdown {
//    enum ColumnAlignment: Equatable { case leading, center, trailing }
//
//    enum Element: Equatable {
//        case text(BlockKind, String, depth: Int, marker: String)
//        case code(String, language: String)
//        case quote(String)
//        case table([[String]], [ColumnAlignment])
//    }
//
//    static func elements(_ text: String) -> [Element] {
//        let source = text as NSString
//        let blocks = scan(text).blocks
//        var result: [Element] = []
//        var index = 0
//        while index < blocks.count {
//            let block = blocks[index]
//            let line = source.substring(with: block.range)
//            if line.trimmingCharacters(in: .whitespaces).isEmpty { index += 1; continue }
//            if block.kind == .codeFence {
//                let language = line.trimmingCharacters(in: .whitespaces).drop { $0 == "`" || $0 == "~" }
//                index += 1
//                var lines: [String] = []
//                while index < blocks.count, blocks[index].kind != .codeFence {
//                    lines.append(source.substring(with: blocks[index].range))
//                    index += 1
//                }
//                if index < blocks.count { index += 1 }
//                result.append(.code(lines.joined(separator: "\n"), language: String(language)))
//                continue
//            }
//            if block.kind == .quote {
//                var lines: [String] = []
//                while index < blocks.count, blocks[index].kind == .quote {
//                    lines.append(source.substring(with: blocks[index].content))
//                    index += 1
//                }
//                result.append(.quote(lines.joined(separator: "\n")))
//                continue
//            }
//            if let table = table(at: index, blocks: blocks, source: source) {
//                result.append(.table(table.rows, table.alignments))
//                index = table.end
//                continue
//            }
//            var content = source.substring(with: block.content)
//            index += 1
//            // A soft line break belongs to the same paragraph, except at a table header.
//            if block.kind == .paragraph {
//                while index < blocks.count, blocks[index].kind == .paragraph {
//                    let next = source.substring(with: blocks[index].content)
//                    if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
//                    if index + 1 < blocks.count,
//                       let cells = tableCells(source.substring(with: blocks[index + 1].range)),
//                       tableAlignments(cells) != nil { break }
//                    content += "\n" + next
//                    index += 1
//                }
//            }
//            result.append(.text(block.kind, content, depth: block.depth, marker: source.substring(with: block.marker)))
//        }
//        return result
//    }
//
//    static func tableRanges(_ text: String) -> [NSRange] { tableRanges(text, document: scan(text)) }
//
//    static func tableRanges(_ text: String, document: Document) -> [NSRange] {
//        let source = text as NSString
//        let blocks = document.blocks
//        var ranges: [NSRange] = []
//        var index = 0
//        while index < blocks.count {
//            if let table = table(at: index, blocks: blocks, source: source) {
//                ranges.append(NSRange(location: blocks[index].range.location, length: NSMaxRange(blocks[table.end - 1].range) - blocks[index].range.location))
//                index = table.end
//            } else { index += 1 }
//        }
//        return ranges
//    }
//
//    private static func table(at index: Int, blocks: [Block], source: NSString) -> (rows: [[String]], alignments: [ColumnAlignment], end: Int)? {
//        guard index + 1 < blocks.count, blocks[index].kind == .paragraph, blocks[index + 1].kind == .paragraph,
//              let header = tableCells(source.substring(with: blocks[index].range)),
//              let delimiters = tableCells(source.substring(with: blocks[index + 1].range)),
//              header.count == delimiters.count, let alignments = tableAlignments(delimiters) else { return nil }
//        var rows = [header]
//        var end = index + 2
//        while end < blocks.count, blocks[end].kind == .paragraph,
//              let cells = tableCells(source.substring(with: blocks[end].range)) {
//            rows.append(Array((cells + Array(repeating: "", count: header.count)).prefix(header.count)))
//            end += 1
//        }
//        return (rows, alignments, end)
//    }
//
//    static func tableCells(_ line: String) -> [String]? {
//        var cells: [String] = []
//        var cell = ""
//        let chars = Array(line.trimmingCharacters(in: .whitespaces))
//        var index = 0
//        var codeDelimiter = 0
//        var separators = 0
//        while index < chars.count {
//            let char = chars[index]
//            if char == "\\", index + 1 < chars.count, chars[index + 1] == "|" {
//                cell.append("|"); index += 2; continue
//            }
//            if char == "`" {
//                var end = index
//                while end < chars.count, chars[end] == "`" { end += 1 }
//                let count = end - index
//                if codeDelimiter == 0 { codeDelimiter = count }
//                else if count == codeDelimiter { codeDelimiter = 0 }
//                cell += String(repeating: "`", count: count)
//                index = end; continue
//            }
//            if char == "|", codeDelimiter == 0 {
//                cells.append(cell.trimmingCharacters(in: .whitespaces)); cell = ""; separators += 1
//            } else { cell.append(char) }
//            index += 1
//        }
//        guard separators > 0 else { return nil }
//        cells.append(cell.trimmingCharacters(in: .whitespaces))
//        if chars.first == "|" { cells.removeFirst() }
//        if chars.last == "|", cells.last == "" { cells.removeLast() }
//        return cells.isEmpty ? nil : cells
//    }
//
//    private static func tableAlignments(_ cells: [String]) -> [ColumnAlignment]? {
//        var alignments: [ColumnAlignment] = []
//        for cell in cells {
//            let dashes = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
//            guard dashes.count >= 3, dashes.allSatisfy({ $0 == "-" }) else { return nil }
//            alignments.append(cell.hasSuffix(":") ? (cell.hasPrefix(":") ? .center : .trailing) : .leading)
//        }
//        return alignments
//    }
//}
