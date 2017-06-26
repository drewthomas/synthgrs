RAW_WDI_CSV=~/data\ sets/WB\ WDI\ 2017/WDIData.csv
WHO_ZIP_DIR=~/data\ sets/WHO\ Mortality\ Database\ 2017-03-29

# Run the R script that makes nice plots of national suicide rates over time
# and does a preliminary synthetic-control analysis.
plots.pdf: country_codes.csv suic_rates.dat wb_gdp.csv wb_to_unmd.dat synthgrs.R
	R -q --vanilla < synthgrs.R
	mv Rplots.pdf plots.pdf

# Use the R script `rates.R` to process the raw WHO Mortality Database CSV
# files and produce the tidy table of suicide rates `suic_rates.dat`.
suic_rates.dat: Morticd10_part1.csv Morticd10_part2.csv Morticd9.csv pop.csv rates.R
	R -q --vanilla < rates.R

# Extract the relevant contents of the WHO Mortality Database ZIP files
# into CSV files in this directory.
#
# `unzip` sets the new CSV files' modification dates to when they were
# `zip`ped, which would normally cause `make` to gratuitously redo the
# `unzip`ping even if the CSV files are already extracted, so `touch` each
# CSV file after extraction to bring its modification date up to date and
# stop `make` from needlessly re-extracting it.
Morticd10_part1.csv Morticd10_part2.csv Morticd9.csv country_codes.csv pop.csv: ${WHO_ZIP_DIR}/*.zip
	unzip ${WHO_ZIP_DIR}/Morticd10_part1*.zip
	mv Morticd10_part1 Morticd10_part1.csv
	touch Morticd10_part1.csv
	unzip ${WHO_ZIP_DIR}/Morticd10_part2*.zip
	mv Morticd10_part2 Morticd10_part2.csv
	touch Morticd10_part2.csv
	unzip ${WHO_ZIP_DIR}/morticd9*.zip
	mv Morticd9 Morticd9.csv
	touch Morticd9.csv
	unzip ${WHO_ZIP_DIR}/country_codes.zip
	mv country_codes country_codes.csv
	touch country_codes.csv
	unzip ${WHO_ZIP_DIR}/Pop.zip
	mv pop pop.csv
	touch pop.csv

# Extract PPP GDP per capita data from the raw (397,057-line!) World Bank
# WDI 2017 CSV data file into a more manageable CSV file.
wb_gdp.csv: ${RAW_WDI_CSV}
	head -n 1 ${RAW_WDI_CSV} | sed 's/,\r*$$//g' > wb_gdp.csv
	grep 'NY\.GDP\.PCAP\.[PK][PD]\.[KZ][DG]' ${RAW_WDI_CSV} \
		| sed 's/,\r*$$//g' >> wb_gdp.csv
