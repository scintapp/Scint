#!/bin/sh
# Polls an endpoint and speaks only when a predicate holds.
#
# The predicate is a jq filter, which is the useful shape here: jq -e already
# exits non-zero on false or null, so "is this interesting yet" needs no
# vocabulary of its own.
#
#   --url=<url>       what to poll
#   --interval=<n>    seconds between polls
#   --check=<filter>  jq filter; fires only when it is true. Empty fires always.
#   --report=<filter> jq filter for what to say on a fire. Defaults to --check.
#   --label=<text>    what to call this observer in its output
#   --times=<n>       stop after n fires; 0 means keep going

URL=""
INTERVAL=60
CHECK=""
REPORT=""
LABEL="Endpoint"
TIMES=0

for arg in "$@"; do
    case "$arg" in
        --url=*) URL="${arg#*=}" ;;
        --interval=*) INTERVAL="${arg#*=}" ;;
        --check=*) CHECK="${arg#*=}" ;;
        --report=*) REPORT="${arg#*=}" ;;
        --label=*) LABEL="${arg#*=}" ;;
        --times=*) TIMES="${arg#*=}" ;;
    esac
done

if [ -z "$URL" ]; then
    echo "$LABEL — no url given."
    exit 64
fi

[ -z "$REPORT" ] && REPORT="$CHECK"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

echo "$LABEL — polling $URL every ${INTERVAL}s."

count=0
while :; do
    body=$(curl -sS --fail-with-body --max-time 30 --location "$URL" 2>&1)
    status=$?

    if [ "$status" -ne 0 ]; then
        echo "$LABEL — request failed at $(stamp): $(printf '%s' "$body" | head -c 300)"
    else
        fired=0
        if [ -z "$CHECK" ]; then
            fired=1
        elif printf '%s' "$body" | jq -e "$CHECK" >/dev/null 2>&1; then
            fired=1
        fi

        if [ "$fired" -eq 1 ]; then
            count=$((count + 1))
            echo "$LABEL — condition met at $(stamp)"

            if [ -n "$REPORT" ]; then
                printf '%s' "$body" | jq -r "$REPORT" 2>/dev/null | head -40
            else
                printf '%s' "$body" | head -c 800
                echo
            fi

            [ "$TIMES" -gt 0 ] && [ "$count" -ge "$TIMES" ] && break
        fi
    fi

    sleep "$INTERVAL"
done

echo "$LABEL — finished after $count fire(s)."
