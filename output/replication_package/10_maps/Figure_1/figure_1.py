### Project name: 
### Script name: main.py
### Created by: Jesse D. Gourevitch
### Language: Python v3.11

### Import packages
import os
import time
import subprocess
import matplotlib
import numpy as np
import pandas as pd
import seaborn as sb
import geopandas as gpd
import matplotlib.pyplot as plt

### Resolve all paths relative to this script's directory so the script
### behaves identically whether launched from its own folder or from the
### project root (e.g., via run_all.R)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

### Read FSF historical losses data to Pandas dataframe
df = pd.read_csv(os.path.join(SCRIPT_DIR, 'historical_losses.zip'))

### Create dictionary with specified flood events
events_dict = {
	'hist1017': 'Hurricane Matthew (2016)',
	'hist1007': 'Hurricane Hermine (2016)',
	'hist1010': 'Hurricane Irma (2017)',
	'hist1006': 'Hurricane Harvey (2017)',
	'hist1018': 'Hurricane Michael (2018)',
	'hist1004': 'Hurricane Florence (2018)'
	}

### Subset FSF dataframe to only include specified events
df = df[df['histid'].isin(events_dict.keys())]

### Subset FSF dataframe to only include observations with >0 depth
df = df[df['hist_depth']>0]

### Get county ID from tract ID
df['county_id'] = df['tract_id'].astype(str).str[:5]

### Read zip code shapefile to Pandas DataFrame
df_counties = gpd.read_file(
    os.path.join(SCRIPT_DIR, 'Boundaries', 'cb_2020_us_county_500k_lower48_proj.zip'))
df_counties = df_counties.to_crs(5070)

### Read states shapefile to Pandas DataFrame
df_states = gpd.read_file(
    os.path.join(SCRIPT_DIR, 'Boundaries', 'cb_2018_us_state_20m_lower48_proj.zip'))
df_states = df_states.to_crs(5070)

### Filter states to show in figure
states = ['01', '05', '12', '13', '21', '22', '28', 
		  '37', '40', '45', '47', '48', '51', '54']
df_states = df_states[df_states['STATEFP'].isin(states)]

### Set plot parameters and style
sb.set(style='ticks')
fig, axes = plt.subplots(figsize=(11, 8), nrows=4, ncols=3)
plt.tight_layout()
plt.subplots_adjust(wspace=0.0, hspace=-0.3)

### Initialize rowcol_dict
rowcol_dict = {
	'0': [0, 0],
	'1': [0, 1],
	'2': [0, 2],
	'3': [2, 0],
	'4': [2, 1],
	'5': [2, 2],
	}	

### Populate legend properties
def create_legend(ax, bins, cmap):
	legend_dict = {}
	legend_dict['legend'] = True
	cax = fig.add_axes([0.999, 0.29, 0.015, 0.61])  # [left, bottom, width, height]
	cax.yaxis.set_label_position('right')
	legend_dict['cax'] = cax
	legend_dict['cmap'] = cmap
	legend_dict['norm'] = matplotlib.colors.BoundaryNorm(
			boundaries=bins, ncolors=len(bins)-1)

	return legend_dict

### Set fontsize
fontsize = 11.5

### Iterate through storm events
for i, histid in enumerate(events_dict.keys()):

	### Set 'ax' based on row, col 
	r, c = rowcol_dict[str(i)]
	ax = axes[r,c]

	### Subset FSF dataframe to histid
	df_histid = df[df['histid']==histid]

	### Plot histograms
	ax_hist = axes[r+1, c]

	### Change size and position of histogarms
	pos = ax_hist.get_position()
	ax_hist.set_position([
		pos.x0 + (pos.width * 0.1), 
		pos.y0 + (pos.height * 0.51), 
		pos.width * 0.85, 
		pos.height * 0.29
		])

	### Plot histogram
	ax_hist.hist(df_histid['hist_depth'][df_histid['hist_depth']<=100], 
		color='grey', bins=50)

	### Format histogram
	ax_hist.tick_params(axis='both', which='both', labelsize=8, length=3)
	ax_hist.set_xticks([0, 20, 40, 60, 80, 100])
	ax_hist.set_xlim(0, 100)
	ax_hist.set_xlabel('Property flood depth (cm)', fontsize=9)
	
	if i == 0:
		ax_hist.set_ylim(0, 5000)
		ax_hist.set_yticks([0, 5000])
	if i == 1:
		ax_hist.set_ylim(0, 1000)
		ax_hist.set_yticks([0, 1000])
	if i == 2:
		ax_hist.set_ylim(0, 1000)
		ax_hist.set_yticks([0, 1000])		
	if i == 3:
		ax_hist.set_ylim(0, 50000)
		ax_hist.set_yticks([0, 50000])
	if i == 4:
		ax_hist.set_ylim(0, 500)
		ax_hist.set_yticks([0, 500])
	if i == 5:
		ax_hist.set_ylim(0, 10000)
		ax_hist.set_yticks([0, 10000])

	### Hide spines
	for j in ['right', 'top']:
		ax_hist.spines[j].set_visible(False)
	for j in ['left', 'bottom']:
		ax_hist.spines[j].set_linewidth(0.8)
	ax_hist.tick_params(width=0.8)

	### Get counts of flooded properties by county
	fips, counts = np.unique(df_histid['county_id'], return_counts=True)

	### Convert counts to dataframe
	df_histid_grouped = pd.DataFrame({
	    'GEOID': fips,
	    'counts': counts})

	### Join counties and counts dataframe
	df_counties_joined = df_counties.merge(df_histid_grouped, on='GEOID', how='left')

	### Create bins
	bins = [0, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000]
	
	### Create colormap
	cmap = plt.get_cmap('PuBuGn', len(bins)-1)

	### Create legend dictionary
	legend_dict = create_legend(ax, bins, cmap)

	### Plot county-level data
	df_counties_joined.plot(
		column='counts', antialiased=False, ec='none', 
		ax=ax, zorder=2, **legend_dict)

	### Plot states
	df_states.plot(ax=ax, ec='w', fc='lightgrey', lw=0.3, zorder=1)

	### Format plot
	ax.set_title(events_dict[histid], y=0.92, fontsize=fontsize)
	ax.set_aspect('equal')
	ax.tick_params(top=False, bottom=False, left=False, right=False,
                labelleft=False, labelbottom=False)
	
	legend_dict['cax'].set_title('N properties\ninundated', 
		fontsize=fontsize, x=2, y=1.03)
	legend_dict['cax'].tick_params(labelsize=fontsize)  
	legend_dict['cax'].set_yticks(bins)
	legend_dict['cax'].set_yticklabels([
		'0', '10', '50', '100', '500', '1,000', '5,000', 
		'10,000', '50,000', '100,000', '500,000'])

	### Hide spines
	for j in ['left', 'right', 'top', 'bottom']:
		ax.spines[j].set_visible(False)


### Save figure
fn = os.path.join(SCRIPT_DIR, 'figure_1.png')
plt.savefig(fn, bbox_inches='tight', dpi=600)

### Open figure (interactive convenience only; skip in batch/headless runs)
if os.environ.get('OPEN_FIGURE') == '1':
    if sys.platform == 'darwin':
        subprocess.run(['open', fn])
    elif sys.platform.startswith('linux'):
        subprocess.run(['xdg-open', fn])
    elif sys.platform == 'win32':
        os.startfile(fn)
        
