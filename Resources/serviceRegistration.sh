#!/bin/bash

LABEL="com.kaechle.Scintd"
SERVICE_NAME="Scintd"
PLIST_SRC="$SRCROOT/Resources/Service.plist"
PLIST_DST=${HOME}/Library/LaunchAgents/${LABEL}.plist
DAEMON_BIN=${BUILT_PRODUCTS_DIR}/${SERVICE_NAME}.xpc/Contents/MacOS/${SERVICE_NAME}

echo "Installing launch agent:"
echo "  label: $LABEL"
echo "  binary: $DAEMON_BIN"
echo "  plist: $PLIST_DST"

SYSTEM_PATH=$(/usr/libexec/path_helper -s | /usr/bin/awk -F'"' '/^PATH=/{print $2}')
if [ -z "$SYSTEM_PATH" ]; then
  SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fi

BREW_PREFIXES="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
PATH_COMBINED="$SYSTEM_PATH"
IFS=":" read -r -a BREW_PARTS <<< "$BREW_PREFIXES"
for entry in "${BREW_PARTS[@]}"; do
  if ! /usr/bin/printf '%s' "$PATH_COMBINED" | /usr/bin/grep -q -F "$entry"; then
    PATH_COMBINED="${PATH_COMBINED}:${entry}"
  fi
done

mkdir -p "$(dirname "$PLIST_DST")"

escape_sed() {
  /usr/bin/printf '%s' "$1" | /usr/bin/sed -e 's/[\\/&]/\\&/g'
}

ENV_SNIPPET=""
if [ -n "$CODEX_HOME" ]; then
  CODEX_HOME_ESCAPED=$(escape_sed "$CODEX_HOME")
  ENV_SNIPPET="		<key>CODEX_HOME</key>\n		<string>${CODEX_HOME_ESCAPED}</string>"
fi

/usr/bin/sed \
  -e "s#__Scint_DAEMON_PATH__#${DAEMON_BIN}#g" \
  -e "s#__Scint_PATH__#${PATH_COMBINED}#g" \
  -e "s#__Scint_ENV_VARS__#${ENV_SNIPPET}#g" \
  "$PLIST_SRC" > "$PLIST_DST"
/bin/launchctl bootout gui/${UID}/${LABEL} 2>/dev/null || true
/bin/launchctl bootstrap gui/${UID} $PLIST_DST
/bin/launchctl enable gui/${UID}/${LABEL}
/bin/launchctl kickstart -k gui/${UID}/${LABEL}

echo "Launch agent ${LABEL} installed and started."
