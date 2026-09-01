#!/bin/bash
# Install the CUPS "universal" filter wrapper that fixes multi-copy printing.
# Run with sudo:  sudo bash install.sh
#
# What this does:
#   1. Backs up the real /usr/lib/cups/filter/universal to universal.real
#   2. Installs universal-wrapper.sh as /usr/lib/cups/filter/universal
#   3. Sets correct ownership/permissions
#   4. Restarts CUPS
#
# The wrapper re-injects the requested copy count into the filter options,
# which fixes "always prints 1 copy" for CUPS raster printers (Epson etc.).

set -e

FILTER_DIR=/usr/lib/cups/filter
REAL="$FILTER_DIR/universal.real"
WRAPPER_SRC="$(dirname "$0")/universal-wrapper.sh"
WRAPPER="$FILTER_DIR/universal"

echo "==> Step 1: backup the real universal filter"
if [ ! -e "$REAL" ]; then
  cp -a "$FILTER_DIR/universal" "$REAL"
  echo "    backed up to $REAL"
else
  echo "    backup already exists: $REAL (not overwriting)"
fi

echo "==> Step 2: install the wrapper"
if [ ! -f "$WRAPPER_SRC" ]; then
  echo "ERROR: wrapper source not found: $WRAPPER_SRC" >&2
  exit 1
fi
install -m 0755 -o root -g root "$WRAPPER_SRC" "$WRAPPER"
echo "    installed $WRAPPER"

echo "==> Step 3: verify"
ls -la "$REAL" "$WRAPPER"
echo "    wrapper first line: $(head -1 "$WRAPPER")"

echo "==> Step 4: restart CUPS"
systemctl restart cups
echo "    CUPS restarted"

echo
echo "DONE. Now test with:  lp -d Epson-L121 -n 3 <file>"
echo "The wrapper re-injects copies=3 into the filter options."
