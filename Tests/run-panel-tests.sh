#!/bin/zsh
set -eu
setopt extended_glob
cd "$(dirname "$0")/.."
products=../.build/Debug
objects=../.build/Intermediates.noindex/Scint.build/Debug/Scint.build/Objects-normal/arm64
panel_test_dir=$(mktemp -d /tmp/scint-panel-tests.XXXXXX)
trap 'rm -rf "$panel_test_dir"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos26.1 -I $products -F $products/PackageFrameworks \
    Tests/PanelRegression.swift $objects/*.o~*/Scint.o $products/*.o -o "$panel_test_dir/panel-tests"
XDG_DATA_HOME=$panel_test_dir XDG_CONFIG_HOME=$panel_test_dir "$panel_test_dir/panel-tests"
