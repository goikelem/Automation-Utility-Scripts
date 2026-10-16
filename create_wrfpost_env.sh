#!/usr/bin/env bash
# ============================================================
# WRF Post-Processing Python Environment
# Location: $WRF_HOME/scripts/
# Environment: wrfpost
# ============================================================

set -Eeuo pipefail

ENV_NAME="wrfpost"
PYTHON_VERSION="3.11"

echo "============================================================"
echo " Creating WRF Post-Processing Conda Environment"
echo "============================================================"

# Check whether Conda is available
if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: Conda was not found in PATH."
    echo "Initialize or install Miniconda/Anaconda, then retry."
    exit 1
fi

# Initialize Conda for this Bash process
CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1091
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Create the environment if it does not already exist
if conda env list | awk '{print $1}' | grep -Fxq "${ENV_NAME}"; then
    echo "Environment '${ENV_NAME}' already exists."
    echo "Updating required packages..."
    conda install -n "${ENV_NAME}" -c conda-forge \
        "python=${PYTHON_VERSION}" \
        wrf-python \
        netcdf4 \
        xarray \
        numpy \
        pandas \
        matplotlib \
        cartopy \
        scipy \
        geopandas \
        rasterio \
        -y
else
    echo "Creating environment '${ENV_NAME}'..."
    conda create -n "${ENV_NAME}" -c conda-forge \
        "python=${PYTHON_VERSION}" \
        wrf-python \
        netcdf4 \
        xarray \
        numpy \
        pandas \
        matplotlib \
        cartopy \
        scipy \
        geopandas \
        rasterio \
        -y
fi

echo
echo "Activating environment '${ENV_NAME}'..."
conda activate "${ENV_NAME}"

echo
echo "Checking installed packages..."
python --version

python - <<'PY'
import importlib

packages = [
    "wrf",
    "netCDF4",
    "xarray",
    "numpy",
    "pandas",
    "matplotlib",
    "cartopy",
    "scipy",
    "geopandas",
    "rasterio",
]

failed = []
for package in packages:
    try:
        module = importlib.import_module(package)
        print(f"OK: {package} {getattr(module, '__version__', '')}")
    except Exception as exc:
        failed.append((package, str(exc)))
        print(f"FAILED: {package}: {exc}")

if failed:
    raise SystemExit("One or more package imports failed.")
PY

echo
echo "============================================================"
echo " WRF Post-Processing Environment Ready"
echo " Environment: ${ENV_NAME}"
echo " Script directory: $WRF_HOME/scripts"
echo "============================================================"
echo
echo "To activate it in a future terminal, run:"
echo "  conda activate ${ENV_NAME}"
