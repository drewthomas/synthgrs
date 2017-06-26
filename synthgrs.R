library(Synth)

# If not already present as the variable `wb_c`, read in the summary metadata
# for each country in the World Bank's 2017 Word Development Indicators
# CSV file.
if (!("wb_c" %in% ls())) {
	wb_c <- read.csv("~/data sets/WB WDI 2017/WDICountry.csv",
	                 header=TRUE)[, 1:5]
}

# If not already present as the variable `wb_gdp`, read in the preprocessed
# table of national PPP GDP per capita and annual growth thereof.
if (!("wb_gdp" %in% ls())) {
	wb_gdp <- read.csv("wb_gdp.csv", header=TRUE)
	for (i in 1:4) {
		wb_gdp[, i] <- as.character(wb_gdp[, i])
	}
	for (i in 5:ncol(wb_gdp)) {
		wb_gdp[, i] <- as.numeric(wb_gdp[, i])
	}
}

# A utility function to pull the variable `ind_code` out of a World Bank WDI
# 2017 table `df` in tidy format for each country-year combination (between
# the years 1960 & 2016).
extract_wb_var <- function(df, ind_code)
{
	df <- df[df[["Indicator.Code"]] == ind_code,]
	if (nrow(df) == 0) {
		return(df)
	}
	out <- data.frame(ABBR=df[["Country.Code"]][1], YR=1960:2016)
	out[[ind_code]] <- unlist(df[1, 5:ncol(df)])
	for (i in 2:nrow(df)) {
		df_sub <- data.frame(ABBR=df[["Country.Code"]][i], YR=1960:2016)
		df_sub[[ind_code]] <- unlist(df[i, 5:ncol(df)])
		out <- rbind(out, df_sub)
	}
	return(out)
}

# Extract PPP GDP (`PG`) and growth therein (`PGG`) into the tidy data
# frame `gdp`.
cat("Extracting national PPP GDP time series...")
gdp <- extract_wb_var(wb_gdp, "NY.GDP.PCAP.KD.ZG")
gdp <- merge(gdp, extract_wb_var(wb_gdp, "NY.GDP.PCAP.PP.KD"))
names(gdp)[3:4] <- c("PGG", "PG")
cat("done\n")

# Retain GDP-related data only for actual countries (decided based on having
# a genuine-looking 2-letter country code).
gdp <- gdp[gdp$ABBR %in% wb_c[grep("[A-WYZ][A-Z]", wb_c[,5]), 1],]

# Throw away countries which didn't show growth in PPP GDP per capita in
# both 2008 and 2009. These are potential controls/donors for the
# synthetic-control analysis.
gdp_rr <- gdp[gdp$ABBR %in% gdp$ABBR[(gdp$YR == 2008) & (gdp$PGG > 0)],]
gdp_rr <- gdp_rr[gdp_rr$ABBR
                 %in% gdp_rr$ABBR[(gdp_rr$YR == 2009) & (gdp_rr$PGG > 0)],]

# Now read in the tidy tables of country-year-sex age-adjusted suicide rates
# and WHO Mortality Database country codes. Splice the country codes into
# the suicide-rate table `sr`.
sr <- read.table("suic_rates.dat", header=TRUE)
cc <- read.csv("country_codes.csv", header=TRUE)
sr <- merge(sr, cc, by.x="Country", by.y="country", all.x=TRUE)

# Make colourful plots of the suicide-rate time series, within each sex
# and for (sex ratio having been adjusted for) whole national populations.
par(las=1, mar=c(4.5, 4, 0.1, 0.1))
for (country_id in unique(sr$Country)) {
	with(sr[sr$Country == country_id,], {
		# Plot the whole-population AASR as a thick black line, then
		# gender-specific AASRs as blue Mars symbols (for males) and
		# red Venus symbols (for females). Label the plot with the
		# country's name (getting rid of the "United Kingdom, " prefix
		# for countries within the UK).
		plot(Year[Sex == unique(Sex)[1]], SAAASR[Sex == unique(Sex)[1]],
		     type="l", lwd=2, xlim=range(sr$Year), ylim=c(0, max(sr$AASR)),
		     xlab="year", ylab="annual age-adjusted suicides per 100k")
		text(Year, AASR, c("\\MA", "\\VE")[Sex],
		     vfont=c("sans serif", "bold"),
		     cex=1.3, col=c("blue", "red")[Sex])
		text(mean(range(sr$Year)), max(sr$AASR), sub(".*, ", "", name)[1])
	})
	grid()
}

# Now the yuckier part. Read in my (incomplete) table mapping World Bank
# 3-letter abbreviations for country names to WHO MD country codes. Link it
# to the GDP table previously winnowed down to just countries which showed
# PPP GDP per capita growth in 2008 & 2009.
wtu <- read.table("wb_to_unmd.dat", header=TRUE)
gdp_rr <- merge(wtu, gdp_rr, by.x="WBABBR", by.y="ABBR")

# Use a join operation to pick out the subset of suicide-rate data for
# countries which had PPP GDP per capita growth in 2008 & 2009. Store that
# subset in `sg`.
sg <- merge(sr, gdp_rr, by.x=c("Country", "Year"), by.y=c("UNMDCC", "YR"),
            all.x=TRUE)
sg$WBABBR <- as.character(sg$WBABBR)

# Now filter `sg` down to only those countries which have complete suicide
# data for 1992 through 2010 (this should amount to 38 rows per country: 19
# years multiplied by 2 sexes per country) -- and also the country I
# arbitrarily picked as the "treated" country (country 5150, or the
# Netherlands) for which to construct a synthetic control.
sg_availability <- aggregate(
	Year ~ WBABBR + Country,
	sg[(sg$Year >= 1992) & (sg$Year <= 2010),],
	length,
	na.action=na.pass
)
cat("Counts of year-sex combinations with suicide rates by country:\n")
print(sg_availability)
sg <- sg[sg$Country %in%
	unique(c(5150, sg_availability$Country[sg_availability$Year == 38]))
,]  # note comma
cat("(38 year-sex combinations needed for inclusion in synthetic control\n)")

# Extract into `saaasr` the sex-adjusted, age-adjusted suicide rates for
# the countries with complete 1992-2010 data.
saaasr <- unique(sg[, c("WBABBR", "Country", "Year", "SAAASR")])
saaasr$WBABBR[is.na(saaasr$WBABBR)] <- saaasr$Country[is.na(saaasr$WBABBR)]
saaasr <- saaasr[saaasr$Year %in% 1992:2010,]

# Prepare `saaasr` for a synthetic-control analysis of my "treated" country,
# just to see what happens.
prepped_saaasr <- dataprep(
	foo=saaasr,
	predictors=c("SAAASR"),
	predictors.op="mean",
	time.predictors.prior=2000:2007,
	dependent="SAAASR",
	unit.variable="Country",
	unit.names.variable="WBABBR",
	time.variable="Year",
#	treatment.identifier=4308,  # UK
	treatment.identifier=5150,  # NZ
	controls.identifier=unique(saaasr$WBABBR[saaasr$WBABBR %in% wtu$WBABBR]),
	time.optimize.ssr=1992:2007,
	time.plot=1992:2010
)

# Actually run the synthetic-control analysis: construct the synthetic
# control with `synth` and then present that synthetic control (i.e. the
# weights assigned to each control/donor country to form the overall
# synthetic control pseudo-country).
#
# The results are underwhelming: of the 100-odd countries with some suicide
# data available, only 2 ("ALB"ania and "KGZ", or "Kyrgyzstan") register
# 2007-2009 per capita growth and have enough suicide data to work as
# controls! So the synthetic control can be made out of only those 2
# countries.
synth_saaasr_result <- synth(prepped_saaasr)
syn_tab <- synth.tab(synth_saaasr_result, prepped_saaasr)
print(syn_tab$tab.pred)
print(syn_tab$tab.w)

# Plot suicide rates over time for the synthetic control and the treated
# country. The poor goodness of fit is unsurprising, given that only 2
# countries are available as donors! This project is a failure.
par(las=1, mar=c(4.5, 4, 0.1, 1))
path.plot(synth.res=synth_saaasr_result,
          dataprep.res=prepped_saaasr,
          Xlab="year",
          Ylab="sex-adjusted and age-adjusted suicide rate")
grid()
