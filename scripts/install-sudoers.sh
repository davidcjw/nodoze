#!/bin/bash
# One-time setup: let the current user run NoDoze's specific pmset commands
# without a password, so it can toggle sleep silently. Scoped to exactly the
# commands the app runs (read-only -g probe + the 6 on/off steps), NOT all of
# pmset. Validates with visudo before installing.
set -euo pipefail

USER_NAME="$(id -un)"
DEST="/etc/sudoers.d/nodoze"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

CMDS="/usr/bin/pmset -g, /usr/bin/pmset -a sleep 0, /usr/bin/pmset -a hibernatemode 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a sleep 1, /usr/bin/pmset -a hibernatemode 3, /usr/bin/pmset -a disablesleep 0"
printf '%s ALL=(root) NOPASSWD: %s\n' "$USER_NAME" "$CMDS" > "$TMP"

# Syntax-check the snippet before it ever touches /etc/sudoers.d.
sudo visudo -cf "$TMP"
sudo install -m 0440 -o root -g wheel "$TMP" "$DEST"

echo "Installed $DEST for user '$USER_NAME'."
echo "NoDoze can now toggle sleep without prompting."
