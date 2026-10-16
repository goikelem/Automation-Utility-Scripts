#!/bin/bash

# Set WRF environment variables
export WRF_HOME="$HOME/Build_WRF"
export WRF_WPS="$HOME/Build_WRF/WPS-4.6.0-ARW"
export WRF_RUN="$HOME/Build_WRF/WRF-4.6.0-ARW/run"

# Prompt user for domain name from terminal
read -p "Enter the domain name: " DOMAIN_NAME

# Check if domain name is empty
if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: Domain name cannot be empty."
    exit 1
fi

# Define the target directory path and export DOMAIN_DIR
export DOMAIN_DIR="$WRF_HOME/$DOMAIN_NAME"

# Create the target directory
mkdir -p "$DOMAIN_DIR"
echo "Created directory: $DOMAIN_DIR"

# Create links from WRF_WPS/*.exe to the created directory
ln -sf "$WRF_WPS"/*.exe "$DOMAIN_DIR"/

# Create link for WRF_WPS/link_grib.csh to the created directory
ln -sf "$WRF_WPS/link_grib.csh" "$DOMAIN_DIR"/

# Create links from WRF_RUN/*.exe to the created directory
ln -sf "$WRF_RUN"/*.exe "$DOMAIN_DIR"/

# Copy namelist.wps and namelist.input so they can be edited independently for this domain
cp "$WRF_WPS/namelist.wps" "$DOMAIN_DIR"/
cp "$WRF_RUN/namelist.input" "$DOMAIN_DIR"/

# Copy required WPS directories for TBL and Vtable files (fixes GEOGRID.TBL errors)
cp -r "$WRF_WPS/geogrid" "$DOMAIN_DIR"/
cp -r "$WRF_WPS/ungrib" "$DOMAIN_DIR"/
cp -r "$WRF_WPS/metgrid" "$DOMAIN_DIR"/

# Create required subdirectories inside the domain directory
mkdir -p "$DOMAIN_DIR"/wrf_output "$DOMAIN_DIR"/GFS_Input "$DOMAIN_DIR"/ECMWF_Input "$DOMAIN_DIR"/Plots
echo "Created subdirectories: wrf_output, GFS_Input, ECMWF_Input, Plots"

# Download download_025_gfs.sh from GitHub to DOMAIN_DIR
echo "Downloading download_025_gfs.sh..."
curl -sSL https://raw.githubusercontent.com/goikelem/Utility-Scripts/main/download_025_gfs.sh -o "$DOMAIN_DIR/download_025_gfs.sh"

# Download auto_run_wrf_with_gfs025.sh from GitHub to DOMAIN_DIR
echo "Downloading auto_run_wrf_with_gfs025.sh..."
curl -sSL https://raw.githubusercontent.com/goikelem/Utility-Scripts/main/auto_run_wrf_with_gfs025.sh -o "$DOMAIN_DIR/auto_run_wrf_with_gfs025.sh"

# Make the downloaded scripts executable
chmod +x "$DOMAIN_DIR/download_025_gfs.sh" "$DOMAIN_DIR/auto_run_wrf_with_gfs025.sh"

# Define source and destination directories
SOURCE="$WRF_RUN"
DEST="$DOMAIN_DIR"

# Link all files and directories, including hidden entries
cp -as "$SOURCE"/. "$DEST"/

# --- Automatically update ~/.bashrc ---
BASHRC="$HOME/.bashrc"
echo "Updating $BASHRC with environment variables..."

# Add base WRF variables if they aren't already there
if ! grep -q "export WRF_HOME=" "$BASHRC"; then
    echo -e "\n# WRF Environment Variables" >> "$BASHRC"
    echo "export WRF_HOME=\"$WRF_HOME\"" >> "$BASHRC"
    echo "export WRF_WPS=\"$WRF_WPS\"" >> "$BASHRC"
    echo "export WRF_RUN=\"$WRF_RUN\"" >> "$BASHRC"
fi

# Update or add DOMAIN_DIR for this specific domain
if grep -q "export DOMAIN_DIR=" "$BASHRC"; then
    sed -i "s|export DOMAIN_DIR=.*|export DOMAIN_DIR=\"$DOMAIN_DIR\"|" "$BASHRC"
else
    echo "export DOMAIN_DIR=\"$DOMAIN_DIR\"" >> "$BASHRC"
fi

# Apply changes to the current terminal session immediately
source "$BASHRC"

# Verify the symbolic links and environment setup
ls -lah "$DEST"
echo "------------------------------------------------------"
echo "Setup complete! All files and links are ready in: $DOMAIN_DIR"
echo "~/.bashrc has been updated with WRF variables and DOMAIN_DIR."
echo "------------------------------------------------------"
