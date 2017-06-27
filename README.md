synthgrs
========

## Context

A little unfinished project, which will very likely remain unfinishable, researching Great Recession suicides. It's inspired by the paper

* Aaron Reeves, Martin McKee, David Stuckler. [Economic suicides in the Great Recession in Europe and North America](http://bjp.rcpsych.org/content/205/3/246), *The British Journal of Psychiatry*, **205**(3), 246&ndash;247

which is basically an [event study](https://en.wikipedia.org/wiki/Event_study) trying to assess how many extra North Americans and Europeans killed themselves in the wake of the Great Financial Crisis.
Reeves, McKee, &amp; Stuckler looked at how the gradients of suicide rates' trajectories steepened in 2008&ndash;2010, using the size of the steepening as an index of extra GFC-provoked suicides.

I thought I'd try reproducing their result from another angle: instead of comparing countries or regions against themselves at different times, I'd compare countries to other countries at the same time.
Countries which saw a recession after the GFC would be "treated" countries where I'd expect more suicides; countries where GDP per capita continued to increase during the GFC would be "control" countries where the suicide trends could serve as baselines.
For each "treated" country I could apply the [synthetic-control method](https://en.wikipedia.org/wiki/Synthetic_control_method): construct a hypothetical control country as a weighted combination of "control" countries, based on pre-GFC suicide rates, then compare the "treated" country to its hypothetical synthetic version during and after the GFC.

It was a nice idea, and conceptually there was no reason it couldn't work: national GDP time series [are publicly available](http://databank.worldbank.org/data/download/WDI_csv.zip) for basically every country, and the World Health Organization publishes a [Mortality Database](http://www.who.int/healthinfo/statistics/mortality_rawdata/en/) with national time series of annual deaths and their causes.
Unfortunately, in practice only about a third of countries had increasing GDP per capita in both 2008 and 2009, only about half of countries had any useable suicide data in the WHO's MD, and there are far fewer countries which had GDP per capita growth *and* had good suicide-rate time series extending back from 2010 to long before the GFC.
Only two countries, in fact: Albania and Kyrgyzstan.
And they're not enough for a control group.

## Output

Still, maybe this project isn't a complete waste of time.
It produced a convenient table of suicide rates, available in this repository as `suic_rates.dat`.
With luck someone else will find the table useful; it's a simple, tab-delimited, plain-text table of suicide rates broken down by country, year, sex, and each of a standard set of age bands (ages 1&ndash;4, ages 5&ndash;9, ages 10&ndash;14, and so on up to age 75+).
The table also has the population counts used as divisors to produce the rates, handy for e.g. setting aside tiny countries where the rates might be suspiciously volatile.

A quick explanation of `suic_rates.dat`'s columns:

* `Country` is the WHO country code. Look it up in `country_codes.csv` for the WHO's actual country name.
* `Year`: self-explanatory. The earliest data come from 1979, but coverage is consistently inconsistent, though least bad for 1985&ndash;1994.
* `Sex`: 1 for males, 2 for females.
* `Deaths1`: total count of suicides across all ages for this country-year-sex combination.
* `D0104` through `D75UP`: count of suicides in each age band for the country-year-sex combination. The first 2 digits represent the lowest age the band includes, the last 2 digits the highest. `D0000` is omitted because I always assume zero suicides at age 0.
* `Pop1`: total population across all ages in this country-year-sex combination.
* `P0000` through `P75UP`: population in each age band in the country-year-sex combination. Numbering scheme is the same as for `D0104` and the like.
* `ASSR0104` through `ASSR75UP`: age-specific suicide rates, i.e. suicides per 100,000 people in the given country-year-sex-age band. Again, I assume zero suicides at age 0.
* `AASR`: age-adjusted suicide rate, i.e. suicides per 100,000 people in the given country-year-sex combination, reweighting the age-specific suicide rates so the overall age distribution matches a reference population (currently the Netherlands in the given year).
* `SAAASR`: sex-adjusted, age-adjusted suicide rate, i.e. suicides per 100,000 people in the given country-year combination, reweighting the AASRs by sex to match a reference population's sex distribution (again that of the Netherlands in the given year).

`plots.pdf` offers a more attractive presentation of the summary suicide rates, consisting of a line plot of sex-and-age-adjusted suicide rates over time for each country in the dataset, and scatterplots of suicide rates broken down further by sex.

## Replication

To check my work from scratch, you'll need the raw data files with which I started.
As GDP data I used the 31 May 2017 version of the World Bank's [World Development Indicators](http://data.worldbank.org/data-catalog/world-development-indicators), and the WHO MD files I used are

* "[Country codes](http://www.who.int/entity/healthinfo/statistics/country_codes.zip?ua=1)", 3 November 2014 version
* "[Population and live births](http://www.who.int/entity/healthinfo/Pop.zip?ua=1)", 29 March 2017 version
* "[Mortality, ICD-9](http://www.who.int/entity/healthinfo/statistics/morticd9.zip?ua=1)", 29 March 2017 version
* "Mortality, ICD-10", parts [1](http://www.who.int/entity/healthinfo/statistics/Morticd10_part1.zip?ua=1) and [2](http://www.who.int/entity/healthinfo/statistics/Morticd10_part2.zip?ua=1), 29 March 2017 versions

It'll be necessary to edit the absolute paths in the `Makefile` and `synthgrs.R` to point to extracted CSV files.

Well-placed effort could very likely improve my work.
I think my table of suicide rates is about as good as the WHO source data, but the WHO source data are clearly not great.

* Annoyingly many countries have suspicious kinks in their WHO population time series (and I've a hunch that those kinks often appear suspiciously close to the time of a census).
* The suicide counts themselves are affected by how reliable countries are in reporting suicides; some countries are surely better than others at recording suicides as suicides.
* I can also be nearly certain that I'm undercounting the suicides represented in the WHO's raw tables which use the ICD-10 taxonomy of causes of death. The main ICD-10 codes for suicide are "X60" through "X84", representing [assorted forms of "Intentional self-harm"](http://apps.who.int/classifications/apps/icd/icd10online2003/fr-icd.htm?gx60.htm+). But the ICD-10 also has the code "Y87.0", for "Sequelae of intentional self harm", and though it sees occasional use in the WHO tables, I set these deaths aside, because I see no corresponding code in the ICD-9 tables. Including the ICD-10 "Y87.0" deaths would therefore produce artifactual jumps in my suicide counts, because the ICD-9 has no counterpart code, so the older data in my time series (based on the ICD-9 taxonomy) would be spuriously lower (because of a lack of "Y87.0" deaths) than the later data (because they'd include the ICD-10 "Y87.0" deaths).
* It's also a commonplace among scholars who study this kind of thing that a lot of suicides fly under the radar and are logged as deaths of uncertain cause. I don't see an easy way to account for that.

It's not all the WHO's fault.
Regarding the suicide counts, they can mostly only work with what they're given by national statistical agencies.
When those agencies drop the ball, as in Poland in 1997 &amp; 1998 and Mauritius in 2009, there's not much the WHO can do.
