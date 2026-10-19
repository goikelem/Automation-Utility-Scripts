#!/bin/bash
# ---------------------------------------------------------------------------
# Download ERA5 reanalysis GRIB data from ECMWF CDS for a sub-region,
# formatted for WPS processing (ungrib.exe).
#
# Usage:   ./download_era5.sh [YYYYMMDD] [START_HR] [END_HR] [STEP_HR]
# Example: ./download_era5.sh 20261011 0 21 3
# Defaults: today (UTC), 0, 21, 3
# ---------------------------------------------------------------------------

# ---------------- User settings ----------------
LEFTLON=20                 # western bound  (deg E)
RIGHTLON=54                # eastern bound  (deg E)
TOPLAT=25                  # northern bound (deg N)
BOTTOMLAT=-10              # southern bound (deg N, negative = south)
OUTDIR="$HOME/ERA5_DATA"
# -----------------------------------------------

DATE="${1:-$(date -u +%Y%m%d)}"
START="${2:-0}"
END="${3:-21}"
STEP="${4:-3}"

YEAR="${DATE:0:4}"
MONTH="${DATE:4:2}"
DAY="${DATE:6:2}"

mkdir -p "$OUTDIR" || exit 1

echo "ERA5 Reanalysis: ${YEAR}-${MONTH}-${DAY} ${START}Z to ${END}Z every ${STEP}h"
echo "Region: ${LEFTLON}E-${RIGHTLON}E, ${BOTTOMLAT}-${TOPLAT}N  ->  $OUTDIR"

# Execute Python script to request data via CDS API
python3 download_era5.py "$YEAR" "$MONTH" "$DAY" "$START" "$END" "$STEP" \
                         "$LEFTLON" "$RIGHTLON" "$TOPLAT" "$BOTTOMLAT" "$OUTDIR"

# ---------------------------------------------------------------------------
# For WPS (run from your WPS directory):
#
# 1. Process 3D Pressure Level Data:
#    ln -sf ungrib/Variable_Tables/Vtable.ERA-interim.pl Vtable
#    ./link_grib.csh $HOME/ERA5_DATA/ERA5_${DATE}_pl.grib
#    (Set prefix='PRES' in namelist.wps)
#    ./ungrib.exe
#
# 2. Process Surface Data:
#    ln -sf ungrib/Variable_Tables/Vtable.ERA-interim.pl Vtable
#    ./link_grib.csh $HOME/ERA5_DATA/ERA5_${DATE}_sfc.grib
#    (Set prefix='SFC' in namelist.wps)
#    ./ungrib.exe
#
# 3. In metgrid.exe (namelist.wps):
#    fg_name = 'PRES', 'SFC'
# ---------------------------------------------------------------------------
