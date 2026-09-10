### Import packages
import os
import re
import time
import matplotlib
import subprocess
import numpy as np
import pandas as pd
import seaborn as sb
import geopandas as gpd
import matplotlib.pyplot as plt

from matplotlib.colors import ListedColormap
from mpl_toolkits.axes_grid1 import make_axes_locatable


### Set plot parameters and style
sb.set(style='ticks')
fig, axes = plt.subplots(figsize=(13.2, 18*1.5), ncols=2, nrows=4)
plt.subplots_adjust(wspace=0.14)

### Initialize path to boundaries shapefile directory
boundaries_dir = 'Boundaries/'

### Initialize path to states shapefile
states_shp_uri = 'Boundaries/cb_2018_us_state_20m_lower48_proj.zip'

### Read states shapefile to GeoPandas dataframe
df_states = gpd.read_file(states_shp_uri)

### Initialize path to counties shapefile
counties_shp_uri = 'Boundaries/cb_2020_us_county_500k_lower48_proj.zip'

### Read counties shapefile to Geopandas dataframe
df_counties = gpd.read_file(counties_shp_uri)
df_counties['fips'] = (df_counties['STATEFP'] + df_counties['COUNTYFP'])
df_counties['fips'] = df_counties['fips'].astype('int64')

### Initialize path to loan data CSV file
xlsx_uri = 'loan_data.xlsx'

### Read HUC summary CSV file to Pandas dataframe
df_present = pd.read_excel(xlsx_uri, sheet_name='PRESENT')
df_future = pd.read_excel(xlsx_uri, sheet_name='FUTURE')

### Merge present and future dataframes
df = df_present.merge(
	df_future, on='fips', how='outer', suffixes=('_present', '_future'))

### Merge counties to dataframe
df = df_counties.merge(df, on='fips', how='left')

### Read FSF property counts CSV to Pandas dataframe
df_fsf = pd.read_csv('fs_data.csv')
df_fsf = df_fsf.rename(columns={'county_id': 'fips'})

### Merge df and df_fsf
df = df.merge(df_fsf, on='fips', how='left')

### Read estimated effects to Pandas dataframe
df_list = []
for i in range (1,5):
	df_coeff = pd.read_csv(f'coeffs/delinq90_inun_fico_{i}_static.csv')
	df_coeff = df_coeff.rename(columns={'Interacted_rel': 'inun'})
	df_coeff['fico'] = i
	df_coeff = df_coeff[['inun', 'fico', 'coef']]
	df_list.append(df_coeff)

df_coeff = pd.concat(df_list)

### Project delinquency rate
def project(df, present_future, recurrance):

	df['total_perc_loans_d90'] = 0

	for inun in ['<0', '1Q', '2Q', '3Q', '4Q']:

		for fico in [1, 2, 3, 4]:

			### Get coeff
			if inun == '<0': 
				coeff = df_coeff['coef'][(df_coeff['inun']=='FFE not flooded') & 
										 (df_coeff['fico']==fico)]

			else:
				coeff = df_coeff['coef'][(df_coeff['inun']==f'FFE flooded {inun}') & 
										 (df_coeff['fico']==fico)]						 

			### Convert series to float
			coeff = float(coeff.iloc[0])

			### Get N loans in group
			inun_group = inun
			
			if inun_group != '<0': 
				inun_group = f'q{inun_group[0]}'
			
			if present_future=='present': 
				flood_year=2020
			
			if present_future=='future': 
				flood_year=2050

			n_loans = (df[f'{present_future}_{recurrance}yr_fico_q{fico}'] * 
				(df[f'propcount_{flood_year}_{recurrance}yr_{inun_group}'] / 
					df[f'propcount_{flood_year}_{recurrance}yr_all']))

			perc_loans_d90 = (n_loans * coeff) / df[f'n_loans_matched_{present_future}']

			df['total_perc_loans_d90'] += perc_loans_d90

	projection = df['total_perc_loans_d90']

	return projection

### Calculate projections
df['present_100yr_projection'] = project(df, 'present', '100')
df['present_500yr_projection'] = project(df, 'present', '500')
df['future_100yr_projection']  = project(df, 'future',  '100')
df['future_500yr_projection']  = project(df, 'future',  '500')

### Calculate percent differences
df['future_100yr_percdiff'] = (
	(df['future_100yr_projection']- df['present_100yr_projection'])  / 
		df['present_100yr_projection'] )

df['future_500yr_percdiff'] = (
	(df['future_500yr_projection'] - df['present_500yr_projection'])  / 
		df['present_500yr_projection'] )


### Populate legend properties
def create_legend(axes, bins, cmap, extend):
	
	### Initialize dictionary to store legend elements
	legend_dict = {}

	### Set legend boolean key to True
	legend_dict['legend'] = True

	### Create colorbar axis
	divider = make_axes_locatable(axes)
	cax = divider.append_axes('right', size='5%', pad=0)	
	
	### Set label position on colorbar axis
	cax.yaxis.set_label_position('right')

	### Set N colors
	if extend=='neither': ncolors = len(bins)-1
	if extend=='max': ncolors = len(bins)
	if extend=='both': ncolors = len(bins)+1

	### Set boundary norm based on bins
	norm = 	matplotlib.colors.BoundaryNorm(
		boundaries=bins, 
		ncolors=ncolors, 
		extend=extend
		)

	### Store legend objects in dictionary
	legend_dict['cax'] = cax
	legend_dict['cmap'] = cmap
	legend_dict['norm'] = norm

	return legend_dict


### Iterate through sub-plots
for i in range(4):

	if i == 0:
		ax = axes[0,0]
		ax_hist = axes[1,0]
		t = '     A'
		col = 'present_100yr_projection'
		bins = [0, 0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04]
		ytick_labels = [f'{b*100:.1f}%' for b in bins]
		extend = 'max'

		base_cmap = plt.get_cmap('BuPu', len(bins)-1)
		new_colors = [base_cmap(i) for i in range(base_cmap.N)]
		cmap = ListedColormap(new_colors)

		hist_range = (0, 0.04)
		hist_xticks = np.arange(0, 0.05, 0.01)
		hist_xticklabls = [f'{b*100:.0f}%' for b in hist_xticks]

	if i == 1:
		ax = axes[0,1]
		ax_hist = axes[1,1]
		t = '     B'
		col = 'present_500yr_projection'	
		bins = [0, 0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04]
		ytick_labels = [f'{b*100:.1f}%' for b in bins]
		extend = 'max'
		
		base_cmap = plt.get_cmap('BuPu', len(bins)-1)
		new_colors = [base_cmap(i) for i in range(base_cmap.N)]
		cmap = ListedColormap(new_colors)

		hist_range = (0, 0.04)
		hist_xticks = np.arange(0, 0.05, 0.01)
		hist_xticklabls = [f'{b*100:.0f}%' for b in hist_xticks]

	if i == 2:
		ax = axes[2,0]
		ax_hist = axes[3,0]
		t = '     C'
		col = 'future_100yr_percdiff'	

		bins = [0, 0.05, 0.1, 0.15, 0.25, 0.3, 0.5]
		# bins = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
		ytick_labels = [f'{b*100:.0f}%' for b in bins]
		extend = 'max'

		base_cmap = plt.get_cmap('YlOrBr', len(bins) - 1)
		new_colors = [base_cmap(i) for i in range(base_cmap.N)]
		cmap = ListedColormap(new_colors)
		
		hist_range = (0, 0.5)
		hist_xticks = np.arange(0, 0.55, 0.1)
		hist_xticklabls = [f'{b*100:.0f}%' for b in hist_xticks]

	if i == 3:
		ax = axes[2,1]
		ax_hist = axes[3,1]
		t = '     D'
		col = 'future_500yr_percdiff'

		bins = [0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.5]
		ytick_labels = [f'{b*100:.0f}%' for b in bins]
		extend = 'max'

		base_cmap = plt.get_cmap('YlOrBr', len(bins) - 1)
		new_colors = [base_cmap(i) for i in range(base_cmap.N)]
		cmap = ListedColormap(new_colors)

		hist_range = (0, 0.5)
		hist_xticks = np.arange(0, 0.55, 0.1)
		hist_xticklabls = [f'{b*100:.0f}%' for b in hist_xticks]


	### Creat legend dictionary
	legend_dict = create_legend(ax, bins, cmap, extend)

	### Plot data
	df.plot(column=col, antialiased=False, lw=0.0, ec='none', 
				ax=ax, zorder=2, **legend_dict)

	### Format legend
	legend_dict['cax'].set_yticks(bins)
	legend_dict['cax'].set_yticklabels(ytick_labels)

	### Plot states
	df_states.plot(ec='none', fc='lightgrey', lw=0.4, ax=ax, zorder=1)
	df_states.plot(ec='k', fc='none', lw=0.4, ax=ax, zorder=5)

	### Plot formatting
	ax.set_title(t, loc='left', fontweight='bold', y=0.95)
	ax.set_xticks([])
	ax.set_yticks([])

	### Hide spines
	for j in ['left', 'right', 'top', 'bottom']:
		ax.spines[j].set_visible(False)

	### Plot histogram in subplot 2
	n, bins, patches =  ax_hist.hist(
		df[col], bins=80, range=hist_range, color='darkgrey')
	
	### Plot axvlines
	ax_hist.axvline(x=np.nanpercentile(df[col], 50), ls='--', color='k', alpha=0.7)
	ax_hist.axvline(x=np.nanpercentile(df[col], 90), ls='--', color='r', alpha=0.8)
	ax_hist.axvline(x=np.nanpercentile(df[col], 99), ls='--', color='darkred', alpha=0.9)

	### Format histogram
	ax_hist.set_xlim(hist_range)
	ax_hist.set_xticks(hist_xticks)
	ax_hist.set_xticklabels(hist_xticklabls)
	ax_hist.patch.set_alpha(0)
	ax_hist.set_ylim(0, 100)
	ax_hist.minorticks_off()
	ax_hist.set_ylabel('N counties')
	ax_hist.spines['right'].set_visible(False)
	ax_hist.spines['top'].set_visible(False)
	ax_hist.set_xlim(hist_range)

	### Change histogram position
	pos = ax_hist.get_position()
	ax_hist.set_position([
		pos.x0 + 0.03, 
		pos.y0 + 0.17, 
		pos.width - 0.08, 
		pos.height * 0.17
		])

	if i == 0 or i == 1:
		pos = ax_hist.get_position()
		ax_hist.set_position([
			pos.x0, 
			pos.y0 + 0.04, 
			pos.width, 
			pos.height
			])

	if i == 2 or i == 3:
		pos = ax.get_position()
		ax.set_position([
			pos.x0, 
			pos.y0 + 0.24, 
			pos.width, 
			pos.height
			])

		pos = ax_hist.get_position()
		ax_hist.set_position([
			pos.x0, 
			pos.y0 + 0.28, 
			pos.width, 
			pos.height
			])

	if i == 0 or i == 2:
		pos = ax.get_position()
		ax.set_position([
			pos.x0 - 0.02, 
			pos.y0, 
			pos.width, 
			pos.height
			])

		pos = ax_hist.get_position()
		ax_hist.set_position([
			pos.x0 - 0.02, 
			pos.y0, 
			pos.width, 
			pos.height
			])


### Save figure
fn = 'figure_4.png'
plt.savefig(fn, bbox_inches='tight', dpi=900)

### Open figure
subprocess.run(['open', fn])

