# Automation-Utility-Scripts

### WRF Utility Preprocessor & Automation Scripts

This repository provides a collection of bash utility scripts designed to automate the Weather Research and Forecasting (WRF) model workflow. Assuming a pre-existing WRF/WPS installation, these scripts handle domain-specific workspace setup, meteorological data retrieval, model execution, and Python post-processing environment configuration.

### 🚀 Key Features
* **Isolated Workspaces:** Quickly generate domain-specific directories with pre-linked executables and namelists.
* **Efficient Data Retrieval:** Server-side subsetting of GFS 0.25° data to save bandwidth and storage.
* **End-to-End Automation:** Automatically updates namelist dates, runs WPS (`geogrid`, `ungrib`, `metgrid`), and executes WRF (`real.exe`, `wrf.exe`).
* **Post-Processing Ready:** Sets up a dedicated Conda environment with `wrf-python`, `cartopy`, `xarray`, and more.

### 📋 Prerequisites
Before using these utilities, ensure your system has:
* A working WRF/WPS installation (default expected at `$HOME/Build_WRF`).
* **System Tools:** `bash`, `curl` or `wget`, `csh/tcsh`.
* **Python:** `conda` (Anaconda or Miniconda) for the post-processing environment setup.

### ⚡ Workflow & Usage

#### 1. Initialize Domain Workspace
**Script:** `setup_wrf_domain.sh`
Creates an isolated working directory for your specific model domain (e.g., `ethiowrf`). It links WPS/WRF executables, copies namelists and Vtables, fetches the other utility scripts, and updates your `~/.bashrc`.
```bash
chmod +x setup_wrf_domain.sh
./setup_wrf_domain.sh
# Enter domain name when prompted (e.g., ethiowrf)
```
*Note: Use a tool like the [WRF Domain Wizard](https://goikelem.github.io/WRF-domain-Wizard/) to generate your `namelist.wps` and `namelist.input` files inside the newly created domain directory.*

#### 2. Download Meteorological Data
**Script:** `download_gfs_025.sh`
Extracts and downloads GFS 0.25° sub-region datasets directly from the NOAA NOMADS server, keeping only the variables and levels required by WRF.
```bash
cd $WRF_HOME/ethiowrf
./download_gfs_025.sh 20261016 00 72  # YYYYMMDD CYCLE FORECAST_HOURS
```

#### 3. Run the Model
**Script:** `run_wrf.sh`
Automates the entire model execution pipeline. It updates namelist time variables, runs WPS, runs `real.exe`, and finally runs `wrf.exe`. It also renames output files for cross-platform compatibility.
```bash
# Automatic mode: Today's date, 00 UTC, 72 hours forecast
./run_wrf.sh --auto 

# Manual mode: Specify date, cycle, and forecast length
./run_wrf.sh 20261016 00 72

# Force geogrid to run (if domain configuration changed)
RUN_GEOGRID=1 ./run_wrf.sh 20261016 00 72
```

#### 4. Configure Post-Processing Environment
**Script:** `create_wrfpost_env.sh`
Builds a Python Conda environment (`wrfpost`) containing all necessary libraries for visualizing and analyzing WRF output.
```bash
cd $WRF_HOME/scripts
chmod +x create_wrfpost_env.sh
./create_wrfpost_env.sh
conda activate wrfpost
```

## 📂 Script Overview
| Script | Purpose |
| :--- | :--- |
| `setup_wrf_domain.sh` | Initializes a domain-specific working directory with links and configs. |
| `download_gfs_025.sh` | Downloads and subsets GFS GRIB2 data from NOMADS. |
| `run_wrf.sh` | Automates namelist updates, WPS, and WRF execution. |
| `create_wrfpost_env.sh` | Builds the Python Conda environment for visualization. |

## 📖 References
* **WRF Model Repository:** [https://github.com/wrf-model/WRF](https://github.com/wrf-model/WRF)
* **WRF Online Tutorial:** [https://www2.mmm.ucar.edu/wrf/OnLineTutorial/](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/)
* **NOAA NOMADS Server:** [https://nomads.ncep.noaa.gov/](https://nomads.ncep.noaa.gov/)
