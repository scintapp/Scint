#!/bin/sh
# Waits until a target moment, fires, and optionally repeats.
#
# Flags arrive as --name=value, because a single-key collection is flattened by Arguments.marshal
# into one argv element. Output is plain text so it falls through Reading into a message chunk.
#
#   --date=<ISO8601> calendar day to fire on; its time of day is ignored
#   --time=<ISO8601> time of day to fire at; its calendar day is ignored
#   --every=<never|hourly|daily|weekly>
#   --label=<text>   what to call this observer in its output
#   --times=<n>      stop after n fires; 0 means keep going
#
# Everything after the flags is the command to fire, already split into argv the way the runtime
# splits it. It is run directly — there is no shell here to quote for.

DATE=""
TIME=""
EVERY="never"
LABEL="Scheduled"
TIMES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --date=*) DATE="${1#*=}"; shift ;;
        --time=*) TIME="${1#*=}"; shift ;;
        --every=*) EVERY="${1#*=}"; shift ;;
        --label=*) LABEL="${1#*=}"; shift ;;
        --times=*) TIMES="${1#*=}"; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

step_for() {
    case "$1" in
        hourly) echo "+1H" ;;
        daily) echo "+1d" ;;
        weekly) echo "+1w" ;;
        *) echo "" ;;
    esac
}

# ISO8601 as Value.formatter writes it, into epoch seconds. `date -j -f` wants the zone spelled
# +HHMM, so Z and +HH:MM are normalised to that first.
epoch() {
    normalized=$(printf '%s' "$1" | sed -e 's/[Zz]$/+0000/' -e 's/\([+-][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
    date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' 2>/dev/null
}

part() { date -r "$1" "+$2"; }
compose() { date -j -f '%Y-%m-%d %H:%M:%S' "$1 $2:00" '+%s' 2>/dev/null; }
advance() { date -j -v"$1" -r "$2" '+%s'; }
stamp() { date '+%Y-%m-%d %H:%M:%S'; }

now=$(date '+%s')
day=""
clock=""

# Date and time arrive as separate instants and only their own half of each is used, so the moment
# is assembled in the local zone. The UI picks a wall-clock time; waiting for the UTC instant its
# ISO8601 spelling names would fire hours off.
if [ -n "$DATE" ]; then
    parsed=$(epoch "$DATE")
    [ -z "$parsed" ] && { echo "$LABEL — could not read a date from '$DATE'."; exit 64; }
    day=$(part "$parsed" '%Y-%m-%d')
fi

if [ -n "$TIME" ]; then
    parsed=$(epoch "$TIME")
    [ -z "$parsed" ] && { echo "$LABEL — could not read a time from '$TIME'."; exit 64; }
    clock=$(part "$parsed" '%H:%M')
fi

if [ -n "$day" ] && [ -n "$clock" ]; then
    target=$(compose "$day" "$clock")
elif [ -n "$day" ]; then
    # A day with no time of day is a morning, the way an all-day reminder is.
    target=$(compose "$day" "09:00")
elif [ -n "$clock" ]; then
    target=$(compose "$(part "$now" '%Y-%m-%d')" "$clock")
    [ -n "$target" ] && [ "$target" -le "$now" ] && target=$(advance '+1d' "$target")
else
    target=$now
fi

[ -z "$target" ] && { echo "$LABEL — could not work out when to fire."; exit 64; }

step=$(step_for "$EVERY")

# A target already behind us would otherwise fire once per missed occurrence, so roll forward to
# the next one still ahead before waiting on anything.
if [ -n "$step" ]; then
    guard=0
    while [ "$target" -le "$now" ]; do
        target=$(advance "$step" "$target") || break
        guard=$((guard + 1))
        [ "$guard" -ge 100000 ] && break
    done
fi

echo "$LABEL — waiting for $(part "$target" '%Y-%m-%d %H:%M:%S %Z') ($EVERY)."

count=0
while :; do
    seconds=$((target - $(date '+%s')))
    [ "$seconds" -gt 0 ] && sleep "$seconds"

    count=$((count + 1))

    if [ $# -gt 0 ]; then
        output=$("$@" 2>&1)
        status=$?
        echo "$LABEL — fired $(stamp) (exit $status)"
        [ -n "$output" ] && echo "$output"
    else
        echo "$LABEL — fired $(stamp)"
    fi

    [ -z "$step" ] && break
    [ "$TIMES" -gt 0 ] && [ "$count" -ge "$TIMES" ] && break

    target=$(advance "$step" "$target") || break
done

echo "$LABEL — finished after $count fire(s)."
