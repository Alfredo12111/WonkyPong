#!/usr/bin/env bash
set -euo pipefail
destination=$(cygpath -u "$WONKYPONG_BUILD_OUTPUT")
export TMPDIR="$(cygpath -m -s /tmp)"
export TEMP="$TMPDIR" TMP="$TMPDIR"
export PATH="/opt/mercury/bin:$PATH"
cd "$destination"
mmc --make --grade hlc.gc.pregen mercury
