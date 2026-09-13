#!/usr/bin/env bash
set -euo pipefail
SCINT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCINT_BUILD="${SCINT_BUILD_DIR:-$SCINT_ROOT/.build/xcode}"
SCINT_MODE="${1:-run}"
case "$SCINT_MODE" in
    run|--debug|--logs|--telemetry|--verify|--build-only) ;;
    *) echo "usage: $0 [--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
cd "$SCINT_ROOT"
if [ "$SCINT_MODE" != "--build-only" ]; then pkill -x Scint >/dev/null 2>&1 || true; fi
SCINT_SKIP_SERVICE_REGISTRATION=NO
if [ "$SCINT_MODE" = "--build-only" ]; then SCINT_SKIP_SERVICE_REGISTRATION=YES; fi
xcodebuild -project Scint.xcodeproj -scheme Scint -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$SCINT_BUILD" \
    SYMROOT="$SCINT_BUILD/Build/Products" OBJROOT="$SCINT_BUILD/Build/Intermediates.noindex" \
    SCINT_SKIP_SERVICE_REGISTRATION="$SCINT_SKIP_SERVICE_REGISTRATION" build
SCINT_APP="$SCINT_BUILD/Build/Products/Debug/Scint.app"
case "$SCINT_MODE" in
    --build-only) exit 0 ;;
    --debug) exec lldb -- "$SCINT_APP/Contents/MacOS/Scint" ;;
    *) /usr/bin/open -n "$SCINT_APP" ;;
esac
case "$SCINT_MODE" in
    --verify) sleep 1; pgrep -x Scint >/dev/null ;;
    --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "Scint"' ;;
    --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.kaechle.scint"' ;;
esac
