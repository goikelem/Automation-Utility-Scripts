#!/bin/bash
# ---------------------------------------------------------------------------
# Download ECMWF IFS 0.25 deg open data GRIB2 files from the ECMWF Portal,
# keeping the global forecast files required by WPS (ungrib).
#
# Usage:   ./download_ecmwf_ifs_025.sh [YYYYMMDD] [START_HR] [END_HR] [STEP_HR]
# Example: ./download_ecmwf_ifs_025.sh 20261011 0 72 3
# Defaults: today (UTC), 0, 120, 3
# ---------------------------------------------------------------------------

# ---------------- User settings ----------------
CYCLE="00"                 # model cycle (00, 06, 12, 18)
OUTDIR="$WRF_HOME/ECMWF_IFS_025"
# -----------------------------------------------

DATE="${1:-$(date -u +%Y%m%d)}"
START="${2:-0}"
END="${3:-120}"
STEP="${4:-3}"

BASE="https://data.ecmwf.int/forecasts"

mkdir -p "$OUTDIR" || exit 1
cd "$OUTDIR" || exit 1

echo "ECMWF IFS 0.25° ${DATE} ${CYCLE}Z  f$(printf %03d $START)-f$(printf %03d $END) every ${STEP} h"
echo "Target Directory -> $OUTDIR"

FAILED=0
for ((h=START; h<=END; h+=STEP)); do
    FHR="${h}"                 # ECMWF open data naming uses unpadded forecast hours (e.g., 0h, 3h, 24h)
    FILE="${DATE}${CYCLE}0000-${FHR}h-oper-fc.grib2"
    OUT="${DATE}${CYCLE}_${FILE}"   # e.g. 2026101100_20261011000000-0h-oper-fc.grib2

    URL="${BASE}/${DATE}/${CYCLE}z/ifs/0p25/oper/${FILE}"

    if [[ -s "$OUT" ]]; then
        echo "[skip] $OUT already exists"
        continue
    fi

    echo "[get ] $OUT"
    curl -sS -f --retry 5 --retry-delay 10 --connect-timeout 30 \
         -o "${OUT}.part" "$URL"

    # A valid GRIB2 file starts with "GRIB"; otherwise the server returned an error page
    if [[ -s "${OUT}.part" && "$(head -c 4 "${OUT}.part")" == "GRIB" ]]; then
        mv "${OUT}.part" "$OUT"
    else
        echo "[FAIL] $OUT (data not yet available or request error)"
        rm -f "${OUT}.part"
        FAILED=$((FAILED+1))
    fi
    sleep 2        # be polite to the ECMWF server
done

echo "Done. Failed files: $FAILED"

# ---------------------------------------------------------------------------
# For WPS (run from your WPS directory):
#   ln -sf $HOME/ECMWF_IFS_025/Vtable.IFS Vtable
#   ./link_grib.csh $HOME/ECMWF_IFS_025/${DATE}${CYCLE}_*
#   ./ungrib.exe
# ---------------------------------------------------------------------------
