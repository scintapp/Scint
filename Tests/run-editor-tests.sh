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
Path(sys.argv[1]).write_text('import Foundation\nstruct Material {\nvar blocks: [Block] = []\n'+s[a:b]+s[c:d]+'}\n')
PY
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer} xcrun swiftc -parse-as-library \
    Sources/ScintEditor/Editor/*.swift "$editor_test_dir/Material.swift" Tests/EditorRegression.swift \
    -o "$editor_test_dir/editor-tests"
"$editor_test_dir/editor-tests"

# An impossible undo must terminate with its operation identified, never disappear.
python3 - "$editor_test_dir/editor-tests" <<'PY'
import subprocess, sys
result = subprocess.run([sys.argv[1], "--invalid-undo"], capture_output=True)
assert result.returncode != 0 and b"Undo failed" in result.stderr, result.stderr.decode()
print("Invalid undo fails loudly with material, block and step diagnostics")
PY
