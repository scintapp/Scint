#!/usr/bin/env bash
set -euo pipefail
SCINT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCINT_BUILD="${SCINT_BUILD_DIR:-$SCINT_ROOT/.build/xcode}"
if [ "${1:-}" != "--skip-build" ]; then "$SCINT_ROOT/script/build_and_run.sh" --build-only; fi
SCINT_PRODUCTS="$SCINT_BUILD/Build/Products/Debug"
SCINT_APP="$SCINT_PRODUCTS/Scint.app/Contents"
SCINT_TEST_DIR="$(mktemp -d "$SCINT_ROOT/.build/tool-regression.XXXXXX")"
for SCINT_TEST in ToolCatalogRegression MCPClientRegression; do
    xcrun swiftc -swift-version 6 -parse-as-library -target "$(uname -m)-apple-macos27.0" \
        -I "$SCINT_PRODUCTS" -F "$SCINT_PRODUCTS/PackageFrameworks" -F "$SCINT_PRODUCTS" \
        "$SCINT_ROOT/Tests/$SCINT_TEST.swift" "$SCINT_APP/MacOS/Scint.debug.dylib" \
        -Xlinker -rpath -Xlinker "$SCINT_APP/MacOS" \
        -Xlinker -rpath -Xlinker "$SCINT_APP/Frameworks" \
        -o "$SCINT_TEST_DIR/$SCINT_TEST"
    XDG_DATA_HOME="$SCINT_TEST_DIR/data" XDG_CONFIG_HOME="$SCINT_TEST_DIR/config" \
        "$SCINT_TEST_DIR/$SCINT_TEST"
done
