#!/bin/sh
# Waits until a target time, fires, and optionally repeats.
#
# Every argument arrives as --name=value, because Renderer.value flattens a
# single-key collection into one argv element. Output is plain text so it falls
# through Reading into a message chunk; anything structured would need a vendor
# table to survive.
#
#   --at=<ISO8601>   first fire time, as Value.formatter writes it (UTC)
#   --every=<once|hourly|daily|weekly>
#   --run=<command>  shell command to run on each fire
#   --label=<text>   what to call this observer in its output
#   --times=<n>      stop after n fires; 0 means keep going

AT=""
EVERY="once"
RUN=""
LABEL="Scheduled"
TIMES=0

for arg in "$@"; do
    case "$arg" in
        --at=*) AT="${arg#*=}" ;;
        --every=*) EVERY="${arg#*=}" ;;
        --run=*) RUN="${arg#*=}" ;;
        --label=*) LABEL="${arg#*=}" ;;
        --times=*) TIMES="${arg#*=}" ;;
    esac
done

step_for() {
    case "$1" in
        hourly) echo "+1h" ;;
        daily) echo "+1d" ;;
        weekly) echo "+1w" ;;
        *) echo "" ;;
    esac
}

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

# An empty or unparseable time means now.
if [ -z "$AT" ]; then
    target=$(dateconv now -f '%Y-%m-%dT%H:%M:%S' 2>/dev/null)
else
    target=$(dateconv "$AT" -f '%Y-%m-%dT%H:%M:%S' 2>/dev/null)
fi

if [ -z "$target" ]; then
    echo "$LABEL — could not read a time from '$AT'."
    exit 64
fi

step=$(step_for "$EVERY")

# A target already in the past would otherwise fire once per missed occurrence,
# so roll forward to the next one still ahead of us before waiting on anything.
if [ -n "$step" ]; then
    guard=0
    while [ "$(datediff now "$target" -f '%S' 2>/dev/null || echo 0)" -le 0 ]; do
        target=$(dateadd "$target" "$step" -f '%Y-%m-%dT%H:%M:%S' 2>/dev/null) || break
        guard=$((guard + 1))
        [ "$guard" -ge 100000 ] && break
    done
fi

echo "$LABEL — waiting for $target UTC ($EVERY)."

count=0
while :; do
    seconds=$(datediff now "$target" -f '%S' 2>/dev/null || echo 0)
    [ "$seconds" -gt 0 ] && sleep "$seconds"

    count=$((count + 1))

    if [ -n "$RUN" ]; then
        output=$(/bin/sh -c "$RUN" 2>&1)
        status=$?
        echo "$LABEL — fired $(stamp) (exit $status)"
        [ -n "$output" ] && echo "$output"
    else
        echo "$LABEL — fired $(stamp)"
    fi

    [ -z "$step" ] && break
    [ "$TIMES" -gt 0 ] && [ "$count" -ge "$TIMES" ] && break

    target=$(dateadd "$target" "$step" -f '%Y-%m-%dT%H:%M:%S' 2>/dev/null) || break
done

echo "$LABEL — finished after $count fire(s)."
