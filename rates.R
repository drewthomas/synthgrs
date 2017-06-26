# rates.R
# compute national time series of age-standardized suicide rates by sex

# Read in the two big tables of mortality counts taxonomized by ICD-10
# category, and merge them into `mort_icd10`.
cat("Reading in death counts in ICD-10 taxonomy...")
mort_icd10_1 <- read.csv("Morticd10_part1.csv", header=TRUE)
mort_icd10_2 <- read.csv("Morticd10_part2.csv", header=TRUE)
mort_icd10 <- rbind(mort_icd10_1, mort_icd10_2)
cat("done\n")

# Read in the big table of (mostly older) mortality counts taxonomized by
# ICD-9 category.
cat("Reading in death counts in ICD-9 taxonomy...")
mort_icd9 <- read.csv("Morticd9.csv", header=TRUE)
cat("done\n")

# Read in the population counts, and throw away those covering only
# subdivisions of countries. Then throw away counts which predate the
# earliest mortality counts.
pop <- read.csv("pop.csv", header=TRUE)
pop <- pop[(pop$SubDiv == "") & is.na(pop$Admin1),]
pop <- pop[pop$Year >= min(c(min(mort_icd9$Year), min(mort_icd10$Year))),]

# Extract the suicide-specific death counts from the merged ICD-10 table.
#
# ICD-10 codes "X60" through "X84" represent "Intentional self-harm". ICD-10
# also includes the code "Y87.0" for "Sequelae of intentional self-harm",
# but that's set aside to lend the final suicide counts greatest compatibility
# with alternative ad hoc disease classifications, and with ICD-9.
#
# A minority of data rows use a different taxonomy, namely "ICD 10 Mortality
# Tabulation List 1", which collapses some 3-character categories together.
# Fortunately "Intentional self-harm" remains its own category with the code
# "1101" (encompassing the familiar standard codes "X60" through "X84").
# Portugal in 2004-2005 also used its own "ICD 10 special list", which
# fortunately also retains "Suicide and intentional self-harm" as a distinct
# category, but with the code "UE63".
cat("Extracting suicide counts from ICD-10 table...")
suic_icd10 <- mort_icd10[(
	substr(mort_icd10$Cause, 1, 2) %in% c("X6", "X7")
	| (mort_icd10$Cause %in% c("X80", "X81", "X82", "X83", "X84",
	                           "1101", "UE63"))
),]  # note comma
cat("done\n")

# Extract the suicide-specific death counts from the merged ICD-9 table.
# ICD-9 Basic Tabulation List code "B54" represents "Suicide and
# self-inflicted injury". China -- or, to be precise, "selected urban and
# rural areas" in China -- use(s) the code "C102" instead.
cat("Extracting suicide counts from ICD-9 table...")
suic_icd9 <- mort_icd9[mort_icd9$Cause %in% c("B54", "C102"),]
cat("done\n")

# Throw away suicide counts which don't represent whole countries.
# (The `SubDiv` and `Admin1` columns can then therefore be thrown away,
# since they're always empty or `NA` in the resulting data frame.)
suic_icd9 <- suic_icd9[(suic_icd9$SubDiv == "") & is.na(suic_icd9$Admin1),
                       c(1, 4:ncol(suic_icd9))]
suic_icd10 <- suic_icd10[
	(
		((suic_icd10$SubDiv == "") | is.na(suic_icd10$SubDiv))
		& is.na(suic_icd10$Admin1)
	),
	c(1, 4:ncol(suic_icd10))
]

# Merge the ICD-9-based suicide counts with the ICD-10-based suicide counts.
# Clean up the `Cause` column's factor levels as well.
suic_icd910 <- rbind(suic_icd9, suic_icd10)
suic_icd910$Cause <- droplevels(suic_icd910$Cause)

my_age_bands_as_col_names <- function(prefix)
{
	return(paste0(prefix,
	              c("0000", "0104", "0509",
	                paste0(seq(10, 70, 5), seq(14, 74, 5)),
	                "75UP")))
}

# Add columns, to a data frame `d` of WHO MD data, which represent my own
# standard age banding of the existing counts in the data frame.
sum_counts_by_fmt_4_age_bands <- function(d, col_prefix)
{

	# Throw away the fine-grained information about infants.
	d <- d[, setdiff(names(d), c("IM_Frmat", paste0("IM_Deaths", 1:4)))]

	# Set up the new columns which are going to contain the counts in my
	# standard (format 4) age bands.
	new_col_names <- my_age_bands_as_col_names(substr(col_prefix, 1, 1))
	for (col_name in new_col_names) {
		d[[col_name]] <- NA
	}

	# Split `d` into subsets according to age banding, using only those
	# rows with useably fine-grained age banding (formats 0 through 4).
	d0 <- d[d$Frmat == 0,]
	d1 <- d[d$Frmat == 1,]
	d2 <- d[d$Frmat == 2,]
	d3 <- d[d$Frmat == 3,]
	d4 <- d[d$Frmat == 4,]

	# Make a list of the names of the old count-containing columns in `d`.
	# The WHO's Mortality Database's tables of deaths and population both
	# have 26 columns (age bands) of counts, so check that there are 26
	# relevant column names.
	old_col_names <- names(d)[grepl(paste0("^", col_prefix), names(d))]
	if (length(old_col_names) != 26) {
		stop(paste0("found ", length(old_col_names),
		            ", not 26, columns of counts"))
	}

	# Fill in the fiddliest new columns according to my standard age bands,
	# lumping together counts in the old bands as appropriate for the old
	# format.
	d0[, new_col_names[2]] <- rowSums(d0[, old_col_names[3:6]])
	d0[, new_col_names[17]] <- rowSums(d0[, old_col_names[21:25]])
	d1[, new_col_names[2]] <- rowSums(d1[, old_col_names[3:6]])
	d1[, new_col_names[17]] <- rowSums(d1[, old_col_names[21:23]])
	d2[, new_col_names[2]] <- d2[, old_col_names[3]]
	d2[, new_col_names[17]] <- rowSums(d2[, old_col_names[21:23]])
	d3[, new_col_names[2]] <- rowSums(d3[, old_col_names[3:6]])
	d3[, new_col_names[17]] <- d3[, old_col_names[21]]
	d4[, new_col_names[2]] <- d4[, old_col_names[3]]
	d4[, new_col_names[17]] <- d4[, old_col_names[21]]

	# Merge the semi-processed subsets of `d` back together, and finish
	# the job by copying old counts over into my new standard age bands.
	d <- rbind(d0, d1, d2, d3, d4)
	d[, new_col_names[1]] <- d[, old_col_names[2]]
	for (col_idx in 3:16) {
		d[, new_col_names[col_idx]] <- d[, old_col_names[4 + col_idx]]
	}

	return(d)

}

# Reconfigure the big table of suicide counts `suic_icd910` to include counts
# banded according to my age-banding scheme. Then throw away the data for
# countries lacking pre-GFC or post-GFC suicide counts.
cat("Re-banding suicide counts...")
suic_banded <- sum_counts_by_fmt_4_age_bands(suic_icd910, "Deaths")
suic_banded <- suic_banded[suic_banded$Country %in%
	unique(suic_banded$Country[suic_banded$Year < 2007])
,]  # note comma
suic_banded <- suic_banded[suic_banded$Country %in%
	unique(suic_banded$Country[suic_banded$Year > 2009])
,]  # note comma
cat("done\n")

# Sum together the fine-grained suicide counts to the country-year-sex level.
cat("Summing suicide counts to country-year-sex level...")
suic_cys <- aggregate(
	cbind(Deaths1, D0104, D0509, D1014, D1519, D2024,
	      D2529, D3034, D3539, D4044, D4549, D5054, D5559,
	      D6064, D6569, D7074, D75UP) ~ Country + Year + Sex,
	suic_banded,
	sum
)
cat("done\n")

# Define a function an interactive user can call to plot time series of each
# country's total suicide counts by sex.
plot_suic_cys <- function()
{
	for (country_id in unique(suic_cys$Country)) {
		with(suic_cys[suic_cys$Country == country_id,], {
			plot(Year, Deaths1, type="n")
			text(Year, Deaths1, c("\\MA", "\\VE")[Sex],
		     	 vfont=c("sans serif", "bold"),
		     	 cex=1.6, col=c("blue", "red")[Sex])
		})
		grid()
	}
}

# Re-band the population counts to use my age-banding scheme, then sum rows
# of counts to produce country-year-sex population numbers.
cat("Summing population counts to country-year-sex level...")
pop_cys <- aggregate(
	cbind(Pop1, P0000, P0104, P0509, P1014, P1519, P2024,
	      P2529, P3034, P3539, P4044, P4549, P5054, P5559,
	      P6064, P6569, P7074, P75UP) ~ Country + Year + Sex,
	sum_counts_by_fmt_4_age_bands(pop, "Pop"),
	sum
)
cat("done\n")

# Join the suicide counts to the population numbers (by country-year-sex
# combination).
sp_counts <- merge(suic_cys, pop_cys)

# From a country-year-sex panel `d` of national suicide rates in my
# standard age bands, pick out a reference country to use for each year's
# standard population, compute age-adjusted suicide rates for each
# country-year-sex combination, and then compute sex-adjusted and age-adjusted
# overall suicide rates for each country-year combination.
compute_suicide_rates <- function(d)
{

	col_names <- my_age_bands_as_col_names("")
	col_names <- col_names[2:length(col_names)]  # set aside age 0

	for (col_name in col_names) {
		assr <- 1e5 * d[paste0("D", col_name)] / d[paste0("P", col_name)]
		d[, paste0("ASSR", col_name)] <- round(assr, 5)
	}

	# Extract population data for a particular country to serve as a rolling
	# standard population. (Country 4210 is the Netherlands, chosen because
	# it's a decent-sized European country with population data running
	# through 2015 and no obvious kinks in its population time series.)
	std_pop <- d[d$Country == 4210,
	             c("Year", "Sex", "Pop1", "P0000", paste0("P", col_names))]
	if (max(std_pop$Year) < max(d$Year)) {
		warning(paste("standard population data ends in", max(std_pop$Year),
		              "and not", max(d$Year)))
	}

	# Compute age-adjusted suicide rates by sex.
	cat("Computing age-adjusted suicide rates by sex...")
	for (yr in unique(d$Year)) {
		for (sex in 1:2) {
			std_sub_pop <- std_pop[(std_pop$Year == yr)
			                       & (std_pop$Sex == sex),]
			std_idxs <- c("P0000", paste0("P", col_names))
			std_sub_pop[std_idxs] <- std_sub_pop[std_idxs] /
			                         	sum(std_sub_pop[std_idxs])
			age_adjust <- function(d_row)
			{
				d_idxs <- which(names(d) %in% paste0("ASSR", col_names))
				return(weighted.mean(c(0.0, d_row[d_idxs]),
				                     std_sub_pop[c("P0000",
				                                   paste0("P", col_names))]))
			}
			d$AASR[(d$Year == yr) & (d$Sex == sex)] <-
				apply(d[(d$Year == yr) & (d$Sex == sex),], 1, age_adjust)
		}
	}
	cat("done\n")

	# Weight the age-adjusted sex-specific suicide rates to produce
	# age-adjusted both-sexes suicide rates.
	cat("Computing age-adjusted and sex-adjusted overall suicide rates...")
	d$SAAASR <- NA
	for (yr in unique(d$Year)) {
		std_sub_pop <- std_pop[(std_pop$Year == yr) & (std_pop$Sex %in% 1:2),]
		std_m <- std_sub_pop$Pop1[std_sub_pop$Sex == 1]
		std_f <- std_sub_pop$Pop1[std_sub_pop$Sex == 2]
		std_tot_pop <- std_m + std_f
		std_m <- std_m / std_tot_pop
		std_f <- std_f / std_tot_pop
		for	(cou in unique(d$Country[d$Year == yr])) {
			d_sub <- d[(d$Country == cou) & (d$Year == yr),]
			if (sum(1:2 %in% d_sub$Sex) < 2) {
				warning(paste("for the year", yr, "country", cou, "has",
				              "suicide counts only for sex", d_sub$Sex))
				d$SAAASR[(d$Country == cou) & (d$Year == yr)] <- NA
			} else {
				d$SAAASR[(d$Country == cou) & (d$Year == yr)] <-
					(std_m * d_sub$AASR[d_sub$Sex == 1]) +
					(std_f * d_sub$AASR[d_sub$Sex == 2])
			}
		}
	}
	cat("done\n")

	# Round the adjusted suicide rates to 3 d.p.; they're close to
	# final output, so lots of spurious precision is unnecessary.
	d$AASR <- round(d$AASR, 3)
	d$SAAASR <- round(d$SAAASR, 3)

	return(d)

}

# Actually compute the final suicide rates, both sex-specific and for both
# sexes considered together.
suic_rates <- compute_suicide_rates(sp_counts)

# After all that work, record the final suicide rates in a tab-delimited
# text file.
write.table(suic_rates, "suic_rates.dat", sep="\t", row.names=FALSE)
