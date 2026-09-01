#!/bin/bash
# CUPS filter wrapper to fix multi-copy ("print N copies") printing.
#
# Background / root cause:
#   cups-filters/libcupsfilters 2.x "cfFilterPDFToPDF" reads the copy count
#   only from the "copies" option in the options string (argv[5]), ignoring
#   the standard CUPS "copies" argument (argv[4]).  CUPS strips the "copies"
#   attribute from argv[5] and passes it only as argv[4], so the copy count
#   is lost and every job prints a single copy.
#
# Fix:
#   Re-inject "copies=<N>" into the options string (argv[5]) so the
#   downstream filter chain (pdftopdf -> ghostscript -> raster) generates
#   the requested number of copies.
#
# Usage (identical to the real "universal" filter):
#   universal job-id user title copies options [filename]

set -e

job=$1
user=$2
title=$3
copies=$4
options=$5
shift 5

# Only modify when a copy count greater than 1 is actually requested.
if [ -n "$copies" ] && [ "$copies" -gt 1 ] 2>/dev/null; then
  # Avoid duplicating an existing copies= option (shouldn't happen, but safe).
  case " $options " in
    *" copies="*|*" Copies="*|*" num-copies="*|*" NumCopies="*) ;;
    *) options="copies=$copies $options" ;;
  esac
fi

exec /usr/lib/cups/filter/universal.real "$job" "$user" "$title" "$copies" "$options" "$@"
