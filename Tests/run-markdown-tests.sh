#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
markdown_test_dir=$(mktemp -d /tmp/scint-markdown-tests.XXXXXX)
trap 'rm -rf "$markdown_test_dir"' EXIT
python3 - "$markdown_test_dir" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
scanner=Path('Sources/ScintEditor/Editor/Markdown.swift').read_text()
scanner=scanner.replace('static func scan(_ text: String) -> Document {', 'static func scan(_ text: String) -> Document {\n        MarkdownScanProbe.shared.record()')
(root/'Markdown.swift').write_text(scanner)
s=Path('Sources/ScintRuntime/Environment/Malleable/Material.swift').read_text()
a=s.index('    enum Block:'); b=s.index('    init(',a); c=s.index('    mutating func insert('); d=s.index('    mutating func delete(from',c)
(root/'Material.swift').write_text('import Foundation\nstruct Material {\nvar blocks: [Block] = []\n'+s[a:b]+s[c:d]+'}\n')
s=Path('Tests/EditorRegression.swift').read_text(); (root/'Runtime.swift').write_text(s[:s.index('@MainActor final class RecordingRenderer')])
s=Path('Sources/Scint/Surfaces/MaterialsSurfaces.swift').read_text(); (root/'TextBlock.swift').write_text('import SwiftUI\nimport AppKit\n'+s[s.index('struct TaskCompletionIndicator:'):s.index('struct MaterialHeader:')])
PY
cat > "$markdown_test_dir/Host.swift" <<'SWIFT'
import AppKit
import SwiftUI
@MainActor enum MenuSurface {
    static var menu: [MenuItem] { [] }
    static func search(_ query: String, kind: MenuKind) -> [MenuItem] { [] }
    static func form(for block: Material.Block) -> (MenuFormKind, MenuFormValues)? { nil }
    static func commit(_ outcome: MenuOutcome, editor: Editor) {}
}
struct MenuPanelHost: View {
    let controller: MenuController
    let isOpen: Bool
    let anchor: CGRect
    let size: CGSize
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void
    var body: some View { EmptyView() }
}
@Observable @MainActor final class ReferenceSelection {
    static let shared = ReferenceSelection()
    var selected: Reference?
}
SWIFT

editor_sources=()
for editor_source in Sources/ScintEditor/Editor/*.swift; do
    if [[ "$editor_source" != */Markdown.swift ]]; then editor_sources+=("$editor_source"); fi
done
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer} xcrun swiftc -parse-as-library \
  "${editor_sources[@]}" "$markdown_test_dir/Markdown.swift" \
  Sources/ScintKit/Views/Tokens/Style.swift \
  Sources/ScintKit/Views/Tokens/Typography.swift \
  Sources/ScintKit/Views/Tokens/MarkdownDocument.swift \
  Sources/ScintKit/Views/Components/MarkdownText.swift \
  Sources/ScintKit/Views/Components/MarkdownTable.swift \
  Sources/ScintEditor/View/*.swift \
  Sources/ScintKit/Menus/MenuTypes.swift Sources/ScintKit/Menus/MenuController.swift \
  "$markdown_test_dir/Material.swift" "$markdown_test_dir/Runtime.swift" \
  "$markdown_test_dir/TextBlock.swift" "$markdown_test_dir/Host.swift" \
  Tests/EditorPerformance.swift Tests/MarkdownRegression.swift -o "$markdown_test_dir/markdown-tests"
"$markdown_test_dir/markdown-tests"
