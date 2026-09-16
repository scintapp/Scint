import Foundation

extension Markdown {
    struct ListContext: Equatable {
        let depth: Int
        let ordinal: Int
        let isOrdered: Bool
    }

    static func prefixLength(of line: String) -> Int {
        let indent = indentLength(of: line)
        let body = (line as NSString).substring(from: indent)
        return indent + markerLength(of: classify(line), in: body)
    }

    static func depth(of line: String) -> Int {
        depth(ofIndent: (line as NSString).substring(to: indentLength(of: line)))
    }

    static func indented(_ line: String, by levels: Int) -> String {
        let kind = classify(line)
        guard kind.isList, levels != 0 else { return line }

        let source = line as NSString
        let current = depth(of: line)
        let target = max(0, current + levels)
        guard target != current else { return line }

        return String(repeating: " ", count: target * indentWidth)
        + source.substring(from: indentLength(of: line))
    }

    static func listContexts(for lines: [String]) -> [ListContext?] {
        var counters: [Int: Int] = [:]
        var previousDepth: Int?

        return lines.map { line -> ListContext? in
            let kind = classify(line)
            guard kind.isList else {
                counters.removeAll()
                previousDepth = nil
                return nil
            }

            let depth = depth(of: line)

            if let previousDepth, depth < previousDepth {
                for level in counters.keys where level > depth { counters[level] = nil }
            }

            let ordinal = (counters[depth] ?? 0) + 1
            counters[depth] = ordinal
            previousDepth = depth

            return ListContext(depth: depth, ordinal: ordinal, isOrdered: kind == .numbered)
        }
    }

}
