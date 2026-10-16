#!/usr/bin/env bash
# =============================================================================
# WRF/WPS run script 
# Author: Goitom Kelem
#
# Usage:
#   ./run_wrf.sh --auto
#   ./run_wrf.sh YYYYMMDD CYCLE FORECAST_HOURS
#
# Examples:
#   ./run_wrf.sh --auto
#   ./run_wrf.sh 20261016 00 72
#
# Required environment:
#   WRF_HOME=/path/to/WRF installation root
#
# Expected layout (adjust WRF_HOME below or export it):
#   $WRF_HOME/ethiowrf/             WPS executables and namelist.wps
#   $WRF_HOME/ethiowrf/             WRF executables and namelist.input
#   $WRF_HOME/ethiowrf/GFS_InputYYYYMMDDCC/ GRIB input files
#   $WRF_HOME/scripts/              this script
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '\n[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$*"; }
require_file() { [[ -f "$1" ]] || die "Required file not found: $1"; }
require_executable() { [[ -x "$1" ]] || die "Required executable not found or not executable: $1"; }

usage() {
    cat <<'USAGE'
Usage:
  run_wrf.sh --auto
  run_wrf.sh YYYYMMDD CYCLE FORECAST_HOURS

Arguments:
  YYYYMMDD        Forecast initialization date in UTC, e.g. 20261016
  CYCLE           00, 06, 12, or 18 UTC
  FORECAST_HOURS  Integer from 1 to 72

Environment:
  WRF_HOME        WRF installation root; must contain ethiowrf/ and scripts/
  REAL_NP         MPI ranks for real.exe (default: 2)
  WRF_NP          MPI ranks for wrf.exe  (default: 8)
USAGE
}

# Find installation root. Export WRF_HOME before running for predictable behavior.
WRF_HOME="${WRF_HOME:-${HOME}/Build_WRF}"
BASE_DIR="${WRF_HOME}/ethiowrf"
SCRIPT_DIR="${WRF_HOME}/scripts"
REAL_NP="${REAL_NP:-2}"
WRF_NP="${WRF_NP:-8}"

[[ -d "$BASE_DIR" ]] || die "Run directory does not exist: $BASE_DIR"
[[ "$REAL_NP" =~ ^[1-9][0-9]*$ ]] || die "REAL_NP must be a positive integer."
[[ "$WRF_NP" =~ ^[1-9][0-9]*$ ]] || die "WRF_NP must be a positive integer."

MODE="case"
if [[ $# -eq 1 && "$1" == "--auto" ]]; then
    MODE="auto"
elif [[ $# -ne 3 ]]; then
    usage
    exit 2
fi

if [[ "$MODE" == "auto" ]]; then
    # Automatically initialize at today's 00 UTC cycle.
    inDate="$(date -u +%Y%m%d)"
    cc="00"
    fc="72"
else
    inDate="$1"
    cc="$2"
    fc="$3"
fi

[[ "$inDate" =~ ^[0-9]{8}$ ]] || die "Date must be YYYYMMDD."
[[ "$cc" =~ ^(00|06|12|18)$ ]] || die "Cycle must be 00, 06, 12, or 18."
[[ "$fc" =~ ^[0-9]+$ ]] || die "Forecast length must be an integer from 1 to 72."
(( fc >= 1 && fc <= 72 )) || die "Forecast length must be between 1 and 72 hours."
date -u -d "${inDate} ${cc}:00:00" '+%Y%m%d%H' >/dev/null 2>&1 || die "Invalid date/cycle: ${inDate} ${cc}."

start_epoch="$(date -u -d "${inDate} ${cc}:00:00" +%s)"
end_epoch=$(( start_epoch + fc * 3600 ))
sYear="$(date -u -d "@${start_epoch}" +%Y)"
sMonth="$(date -u -d "@${start_epoch}" +%m)"
sDay="$(date -u -d "@${start_epoch}" +%d)"
sHour="$(date -u -d "@${start_epoch}" +%H)"
eYear="$(date -u -d "@${end_epoch}" +%Y)"
eMonth="$(date -u -d "@${end_epoch}" +%m)"
eDay="$(date -u -d "@${end_epoch}" +%d)"
eHour="$(date -u -d "@${end_epoch}" +%H)"

cDate="${inDate}${cc}"
gribdir="${BASE_DIR}/GFS_Input${cDate}"
wrfdir="${BASE_DIR}/wrf_output/${cDate}"
mkdir -p "$wrfdir"

start_stamp="${sYear}-${sMonth}-${sDay}_${sHour}:00:00"
end_stamp="${eYear}-${eMonth}-${eDay}_${eHour}:00:00"
start_date="start_date = '${start_stamp}'"
end_date="end_date = '${end_stamp}'"

wps_namelist="${BASE_DIR}/namelist.wps"
WRF_RUN_DIR="${WRF_RUN_DIR:-$BASE_DIR}"
wrf_namelist="${WRF_RUN_DIR}/namelist.input"
require_file "$wps_namelist"
require_file "$wrf_namelist"
require_executable "${BASE_DIR}/geogrid.exe"
require_executable "${BASE_DIR}/ungrib.exe"
require_executable "${BASE_DIR}/metgrid.exe"
require_executable "${BASE_DIR}/real.exe"
require_executable "${BASE_DIR}/wrf.exe"
require_executable "${BASE_DIR}/link_grib.csh"
[[ -d "$gribdir" ]] || die "GRIB input directory not found: $gribdir"

run_start="$(date -u +%s)"
log "WRF run started. Date=${inDate}, cycle=${cc} UTC, forecast=${fc} hours"
log "Input GRIB directory: $gribdir"
log "Output directory: $wrfdir"

# Back up namelists before editing them.
cp -p "$wps_namelist" "${wps_namelist}.bak.$(date -u +%Y%m%dT%H%M%S)"
cp -p "$wrf_namelist" "${wrf_namelist}.bak.$(date -u +%Y%m%dT%H%M%S)"

# Replace a namelist assignment while preserving the number of comma-separated
# values already present (supports d01...d0N rather than assuming 3 domains).
set_namelist_value() {
    local file="$1" key="$2" value="$3"
    KEY="$key" VALUE="$value" FILE="$file" python3 - <<'PY'
import os, re, sys
path, key, value = os.environ["FILE"], os.environ["KEY"], os.environ["VALUE"]
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
found = False
pat = re.compile(r"^(\s*" + re.escape(key) + r"\s*=\s*)(.*?)(\s*(?:!.*)?)(\r?\n?)$", re.I)
for i, line in enumerate(lines):
    m = pat.match(line)
    if not m:
        continue
    old = m.group(2).strip()
    # Keep the existing number of domain entries where possible.
    count = max(1, old.count(",") + (0 if old.endswith(",") else 1))
    vals = ", ".join([value] * count)
    if old.endswith(","):
        vals += ","
    lines[i] = m.group(1) + vals + m.group(3) + m.group(4)
    found = True
    break
if not found:
    print(f"ERROR: namelist key '{key}' not found in {path}", file=sys.stderr)
    sys.exit(3)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PY
}

log "Updating namelist.wps dates"
set_namelist_value "$wps_namelist" start_date "'${start_stamp}'"
set_namelist_value "$wps_namelist" end_date "'${end_stamp}'"

# geogrid normally needs to run only when the domain/geography settings change.
# Set RUN_GEOGRID=1 to run it; default skips it to save time.
if [[ "${RUN_GEOGRID:-0}" == "1" ]]; then
    log "Running geogrid.exe"
    (cd "$BASE_DIR" && ./geogrid.exe > log.geogrid 2>&1) || {
        tail -n 60 "$BASE_DIR/log.geogrid" >&2 || true
        die "geogrid.exe failed; see $BASE_DIR/log.geogrid"
    }
else
    log "Skipping geogrid.exe (set RUN_GEOGRID=1 to run it)"
fi

log "Linking GRIB files"
(
    cd "$BASE_DIR"
    # Remove old GRIBFILE links so the new cycle cannot mix with old inputs.
    rm -f GRIBFILE.*
    ./link_grib.csh "${gribdir}/" 
) || die "Failed to link GRIB input files."

# GFS Vtable is appropriate only when the source data are GFS.
ln -sfn ungrib/Variable_Tables/Vtable.GFS "${BASE_DIR}/Vtable"

log "Running ungrib.exe"
(
    cd "$BASE_DIR"
    ./ungrib.exe > log.ungrib 2>&1
) || {
    tail -n 60 "$BASE_DIR/log.ungrib" >&2 || true
    die "ungrib.exe failed; see $BASE_DIR/log.ungrib"
}

log "Running metgrid.exe"
(
    cd "$BASE_DIR"
    ./metgrid.exe > log.metgrid 2>&1
) || {
    tail -n 60 "$BASE_DIR/log.metgrid" >&2 || true
    die "metgrid.exe failed; see $BASE_DIR/log.metgrid"
}

# Update WRF run dates, using the actual start cycle and end time.
log "Updating namelist.input"
set_namelist_value "$wrf_namelist" run_hours "$fc"
set_namelist_value "$wrf_namelist" start_year "$sYear"
set_namelist_value "$wrf_namelist" start_month "$((10#$sMonth))"
set_namelist_value "$wrf_namelist" start_day "$((10#$sDay))"
set_namelist_value "$wrf_namelist" start_hour "$((10#$sHour))"
set_namelist_value "$wrf_namelist" end_year "$eYear"
set_namelist_value "$wrf_namelist" end_month "$((10#$eMonth))"
set_namelist_value "$wrf_namelist" end_day "$((10#$eDay))"
set_namelist_value "$wrf_namelist" end_hour "$((10#$eHour))"

# Run real.exe and wrf.exe from the directory containing WRF executables.
# This assumes WPS and WRF executables/namelists share BASE_DIR, as in the
# original script. If your WRF run directory is separate, set WRF_RUN_DIR.
require_executable "${WRF_RUN_DIR}/real.exe"
require_executable "${WRF_RUN_DIR}/wrf.exe"

log "Running real.exe with ${REAL_NP} MPI rank(s)"
(
    cd "$WRF_RUN_DIR"
    mpirun -np "$REAL_NP" ./real.exe > log.real 2>&1
) || {
    tail -n 80 "${WRF_RUN_DIR}/log.real" >&2 || true
    die "real.exe failed; see ${WRF_RUN_DIR}/log.real"
}

log "Running wrf.exe with ${WRF_NP} MPI rank(s)"
(
    cd "$WRF_RUN_DIR"
    mpirun -np "$WRF_NP" ./wrf.exe > log.wrf 2>&1
) || {
    tail -n 80 "${WRF_RUN_DIR}/log.wrf" >&2 || true
    die "wrf.exe failed; see ${WRF_RUN_DIR}/log.wrf"
}

# Move output files and replace colon characters in timestamps with underscores.
shopt -s nullglob
outputs=( "${WRF_RUN_DIR}"/wrfout_* )
if (( ${#outputs[@]} )); then
    for file in "${outputs[@]}"; do
        [[ -f "$file" ]] || continue
        name="$(basename "$file")"
        safe_name="${name//:/_}"
        safe_name="${safe_name//-/_}"
        mv -- "$file" "${wrfdir}/${safe_name}"
    done
else
    log "WARNING: No wrfout_* files found in ${WRF_RUN_DIR}"
fi

# Clean temporary metgrid links/files from the WRF run directory only.
find "$WRF_RUN_DIR" -maxdepth 1 -type l -name 'met_em*' -delete
find "$WRF_RUN_DIR" -maxdepth 1 -type f -name 'met_em*' -delete

run_end="$(date -u +%s)"
elapsed=$(( run_end - run_start ))
printf '\nWRF run completed.\n'
printf 'Output directory: %s\n' "$wrfdir"
printf 'Elapsed time: %d hour(s), %d minute(s), %d second(s)\n' \
    "$((elapsed / 3600))" "$(((elapsed % 3600) / 60))" "$((elapsed % 60))"
