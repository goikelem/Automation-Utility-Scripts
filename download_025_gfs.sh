#!/bin/bash
# ---------------------------------------------------------------------------
# Download GFS 0.25 deg (gfs.t00z.pgrb2.0p25) for a sub-region from NOMADS,
# keeping only the variables/levels required by Vtable_0.25.GFS.
#
# Usage:  ./download_gfs_025.sh [YYYYMMDD] [START_HR] [END_HR] [STEP_HR]
# Example: ./download_gfs_025.sh 20261011 0 72 3
# Defaults: today (UTC), 0, 120, 3
# ---------------------------------------------------------------------------

# ---------------- User settings ----------------
CYCLE="00"                 # model cycle (t00z)
LEFTLON=20                 # western bound  (deg E)
RIGHTLON=54                # eastern bound  (deg E)
TOPLAT=25                  # northern bound (deg N)
BOTTOMLAT=-10              # southern bound (deg N, negative = south)
OUTDIR="$HOME/GFS_025"
# -----------------------------------------------

DATE="${1:-$(date -u +%Y%m%d)}"
START="${2:-0}"
END="${3:-120}"
STEP="${4:-3}"

BASE="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl"

# Variables selected from the Vtable (13)
VARS="HGT ICEC LAND MSLET PRES RH SNOD SOILW TMP TSOIL UGRD VGRD WEASD"

# 41 isobaric levels (hPa) + surface-type levels
PLEVS="1000 975 950 925 900 850 800 750 700 650 600 550 500 450 400 350 300 250 200 150 100 70 50 40 30 20 15 10 7 5 3 2 1 0.7 0.4 0.2 0.1 0.07 0.04 0.02 0.01"
OTHER_LEVS="2_m_above_ground 10_m_above_ground surface mean_sea_level \
0-0.1_m_below_ground 0.1-0.4_m_below_ground 0.4-1_m_below_ground 1-2_m_below_ground \
max_wind tropopause"

# Build the query-string pieces once
QS=""
for v in $VARS; do QS+="&var_${v}=on"; done
for l in $PLEVS; do QS+="&lev_${l}_mb=on"; done
for l in $OTHER_LEVS; do QS+="&lev_${l}=on"; done
QS+="&subregion=&leftlon=${LEFTLON}&rightlon=${RIGHTLON}&toplat=${TOPLAT}&bottomlat=${BOTTOMLAT}"
QS+="&dir=%2Fgfs.${DATE}%2F${CYCLE}%2Fatmos"

mkdir -p "$OUTDIR" || exit 1
cd "$OUTDIR" || exit 1

echo "GFS ${DATE} ${CYCLE}Z  f$(printf %03d $START)-f$(printf %03d $END) every ${STEP} h"
echo "Region: ${LEFTLON}E-${RIGHTLON}E, ${BOTTOMLAT}-${TOPLAT}N  ->  $OUTDIR"

FAILED=0
for ((h=START; h<=END; h+=STEP)); do
    FHR=$(printf "%03d" "$h")
    FILE="gfs.t${CYCLE}z.pgrb2.0p25.f${FHR}"
    OUT="${DATE}${CYCLE}_${FILE}"       # e.g. 2026101100_gfs.t00z.pgrb2.0p25.f000

    if [[ -s "$OUT" ]]; then
        echo "[skip] $OUT already exists"
        continue
    fi

    echo "[get ] $OUT"
    curl -sS -f --retry 5 --retry-delay 10 --connect-timeout 30 \
         -o "${OUT}.part" "${BASE}?file=${FILE}${QS}"

    # A valid GRIB2 file starts with "GRIB"; otherwise NOMADS returned an error page
    if [[ -s "${OUT}.part" && "$(head -c 4 "${OUT}.part")" == "GRIB" ]]; then
        mv "${OUT}.part" "$OUT"
    else
        echo "[FAIL] $OUT (data not yet available or request error)"
        rm -f "${OUT}.part"
        FAILED=$((FAILED+1))
    fi
    sleep 2        # be polite to NOMADS
done

echo "Done. Failed files: $FAILED"

# ---------------------------------------------------------------------------
# For WPS (run from your WPS directory):
#   ln -sf $HOME/GFS_025/Vtable_0.25.GFS Vtable
#   ./link_grib.csh $HOME/GFS_025/${DATE}${CYCLE}_gfs.t${CYCLE}z.pgrb2.0p25.f*
#   ./ungrib.exe
# ---------------------------------------------------------------------------
