#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
editor_test_dir=$(mktemp -d /tmp/scint-editor-tests.XXXXXX)
trap 'rm -rf "$editor_test_dir"' EXIT
python3 - "$editor_test_dir/Material.swift" <<'PY'
from pathlib import Path
import sys
s=Path('Sources/ScintRuntime/Environment/Malleable/Material.swift').read_text()
a=s.index('    enum Block:'); b=s.index('    init(',a)
c=s.index('    mutating func insert('); d=s.index('    mutating func delete(from',c)
Path(sys.argv[1]).write_text('import Foundation\nstruct Material {\nprivate(set) var blocks: [Block] = []\n'+s[a:b]+s[c:d]+'}\n')
PY
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer} xcrun swiftc -parse-as-library -swift-version 6 \
    Sources/ScintEditor/Core/ScintEditor.swift Sources/ScintEditor/Views/*.swift Sources/ScintEditor/Model/*.swift Sources/ScintEditor/Markdown/*.swift \
    Sources/ScintKit/Views/Tokens/MarkdownDocument.swift Sources/ScintKit/Menus/MenuTypes.swift Sources/ScintKit/Menus/MenuController.swift \
    "$editor_test_dir/Material.swift" Tests/EditorRegression.swift -o "$editor_test_dir/editor-tests"
"$editor_test_dir/editor-tests"
