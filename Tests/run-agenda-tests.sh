#!/bin/zsh
set -eu
setopt extended_glob
cd "$(dirname "$0")/.."
products=../.build/Debug
objects=../.build/Intermediates.noindex/Scint.build/Debug/Scint.build/Objects-normal/arm64
agenda_test_dir=$(mktemp -d /tmp/scint-agenda-tests.XXXXXX)
trap 'rm -rf "$agenda_test_dir"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos26.1 -I $products -F $products/PackageFrameworks \
    Tests/AgendaRegression.swift $objects/*.o~*/Scint.o $products/*.o -o "$agenda_test_dir/agenda-tests"
cp -R $products/ScintComponents_ScintComponents.bundle "$agenda_test_dir/"
XDG_DATA_HOME=$agenda_test_dir XDG_CONFIG_HOME=$agenda_test_dir "$agenda_test_dir/agenda-tests"
