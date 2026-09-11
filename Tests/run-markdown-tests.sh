#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
markdown_test_dir=$(mktemp -d /tmp/scint-markdown-tests.XXXXXX)
trap 'rm -rf "$markdown_test_dir"' EXIT
# Compile the production native editor view without the unrelated SwiftUI session adapter.
python3 - "$markdown_test_dir/EditorRegression.swift" <<'PYTEST'
from pathlib import Path
import sys
source = Path("Sources/ScintEditor/Core/EditorInput.swift").read_text()
view = source[source.index("final class EditorInputView:"):]
tests = Path("Tests/MarkdownRegression.swift").read_text()
Path(sys.argv[1]).write_text("import AppKit\nimport SwiftUI\n" + view + "\n" + tests)
PYTEST
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun swiftc -parse-as-library \
  Sources/ScintKit/Views/Tokens/Style.swift \
  Sources/ScintKit/Views/Tokens/Typography.swift \
  Sources/ScintKit/Views/Tokens/MarkdownDocument.swift \
  Sources/ScintKit/Views/Components/MarkdownText.swift \
  Sources/ScintKit/Views/Components/MarkdownTable.swift \
  Sources/ScintKit/Views/Components/Blocks.swift \
  Sources/ScintEditor/Core/EditorThemer.swift \
  Sources/ScintEditor/Core/EditorAttachments.swift \
  "$markdown_test_dir/EditorRegression.swift" \
  -o "$markdown_test_dir/markdown-tests"
"$markdown_test_dir/markdown-tests"
