#!/bin/bash
# Undo install-sudoers.sh.
set -euo pipefail
sudo rm -f /etc/sudoers.d/nodoze
echo "Removed /etc/sudoers.d/nodoze."
