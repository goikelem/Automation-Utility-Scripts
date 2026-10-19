#!/usr/bin/env python3
import sys
import cdsapi

if len(sys.argv) < 6:
    print("Usage: python3 download_era5.py YYYY MM DD START_HR END_HR STEP_HR LEFTLON RIGHTLON TOPLAT BOTTOMLAT OUTDIR")
    sys.exit(1)

year      = sys.argv[1]
month     = sys.argv[2]
day       = sys.argv[3]
start_hr  = int(sys.argv[4])
end_hr    = int(sys.argv[5])
step_hr   = int(sys.argv[6])
leftlon   = float(sys.argv[7])
rightlon  = float(sys.argv[8])
toplat    = float(sys.argv[9])
bottomlat = float(sys.argv[10])
outdir    = sys.argv[11]

# Format bounding box for CDS: [North, West, South, East]
area = [toplat, leftlon, bottomlat, rightlon]
hours = [f"{h:02d}:00" for h in range(start_hr, end_hr + 1, step_hr)]

c = cdsapi.Client()

# 1. Download Surface (2D) Data
sfc_file = f"{outdir}/ERA5_{year}{month}{day}_sfc.grib"
print(f"--> Requesting Surface data: {sfc_file}")
c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'product_type': 'reanalysis',
        'format': 'grib',
        'variable': [
            '10m_u_component_of_wind', '10m_v_component_of_wind',
            '2m_dewpoint_temperature', '2m_temperature',
            'land_sea_mask', 'mean_sea_level_pressure',
            'sea_ice_cover', 'sea_surface_temperature',
            'skin_temperature', 'snow_depth', 'soil_type',
            'surface_pressure', 'volumetric_soil_water_layer_1',
            'volumetric_soil_water_layer_2', 'volumetric_soil_water_layer_3',
            'volumetric_soil_water_layer_4', 'soil_temperature_level_1',
            'soil_temperature_level_2', 'soil_temperature_level_3',
            'soil_temperature_level_4'
        ],
        'year': year,
        'month': month,
        'day': day,
        'time': hours,
        'area': area,
    },
    sfc_file
)

# 2. Download Pressure Levels (3D) Data
pl_file = f"{outdir}/ERA5_{year}{month}{day}_pl.grib"
print(f"--> Requesting Pressure Levels data: {pl_file}")
c.retrieve(
    'reanalysis-era5-pressure-levels',
    {
        'product_type': 'reanalysis',
        'format': 'grib',
        'variable': [
            'geopotential', 'relative_humidity', 'specific_humidity',
            'temperature', 'u_component_of_wind', 'v_component_of_wind'
        ],
        'pressure_level': [
            '1', '2', '3', '5', '7', '10', '20', '30', '50', '70',
            '100', '125', '150', '175', '200', '225', '250', '300',
            '350', '400', '450', '500', '550', '600', '650', '700',
            '750', '775', '800', '825', '850', '875', '900', '925',
            '950', '975', '1000'
        ],
        'year': year,
        'month': month,
        'day': day,
        'time': hours,
        'area': area,
    },
    pl_file
)
