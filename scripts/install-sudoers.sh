#!/bin/bash
# One-time setup: let the current user run /usr/bin/pmset without a password,
# so NoDoze can toggle sleep silently. Validates with visudo before installing.
set -euo pipefail

USER_NAME="$(id -un)"
DEST="/etc/sudoers.d/nodoze"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset\n' "$USER_NAME" > "$TMP"

# Syntax-check the snippet before it ever touches /etc/sudoers.d.
sudo visudo -cf "$TMP"
sudo install -m 0440 -o root -g wheel "$TMP" "$DEST"

echo "Installed $DEST for user '$USER_NAME'."
echo "NoDoze can now toggle sleep without prompting."
