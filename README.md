# Delta_Flight_Delays
An analysis of Delta flight delays using R with geographical mapping
# Delta Flight Delay Analysis: Spatial Patterns Across the Contiguous U.S.

## Problem

Flight delays create operational inefficiencies across the airline industry. This project 
investigates Delta Airlines' delay patterns to identify whether delays cluster geographically, 
what causes them, and whether there are seasonal trends — insights that could help pinpoint 
operational bottlenecks and inform efficiency improvements.

**Research questions:**
- What are the primary causes of Delta flight delays, and do they vary by geographic area?
- Is there evidence of spatial autocorrelation or clustering in Delta's delays?
- How does delay time vary by geographic location?

## Data

- **Source:** U.S. Bureau of Transportation Statistics (On-Time Delay Cause data), July 2024–July 2025
- **Scope:** Delta Airlines flights, contiguous 48 states
- **Airport coordinates:** merged in via IATA code from a supplementary Kaggle airlines dataset
- **Delay categories:** carrier, weather, National Air System (NAS), security, late aircraft

**Processing steps:**
- Filtered to contiguous U.S. airports with valid coordinates; dropped N/A values (retained zero-delay records as valid)
- Aggregated from monthly per-airport rows to one row per airport (summed delays)
- Derived a "primary delay cause" field per airport based on the largest delay category
- Reprojected coordinates (EPSG 9311) to convert degrees to meters for spatial analysis

## Methods

- Mapped average delay per flight and primary delay cause by airport using `ggplot()`
- Tested for global spatial autocorrelation with **Moran's I** (5 nearest neighbors, spatial weights matrix via `sp`)
- Ran **Local Moran's I (LISA)** to identify local hot/cold spots, plotting z-scores to flag significance
- Aggregated delays by month to visualize seasonal trends

## Results

- **Average delay:** Most airports clustered around 10–20 minutes per flight, with no strong visual pattern of clustering
- **Primary cause:** Carrier-related issues dominated nationwide; late aircraft and NAS delays appeared at select airports; weather and security were not the primary cause anywhere
- **Moran's I:** 0.038 (p = 0.171) — no statistically significant global spatial clustering
- **LISA:** Consistent with the global result; only one notable hotspot (North Dakota) and one cold spot (Minnesota)
- **Seasonality:** Delays peaked in July 2024 and July 2025, dropped to a low in October 2024, with a modest winter uptick

## Key Findings

Delta's delays are driven primarily by **operational factors, not geography** — carrier-related 
issues (specific to individual aircraft) explain most of the variation, consistent with the lack 
of spatial clustering. **Seasonality**, particularly peak summer travel demand, showed far more 
explanatory power than location.

## Next Steps

- Incorporate additional carriers for comparison
- Test finer-grained temporal clustering (day-of-week, time-of-day)
- Explore whether specific carrier-side operational metrics (turnaround time, fleet age at airport) explain the carrier-delay dominance

## Tools

R (`ggplot2`, `sp`, spatial statistics packages for Moran's I / LISA)

## References

- Haroon, S. A. (2023). *Airlines Dataset* [Data set]. Kaggle.
- Bureau of Transportation Statistics. (2024). *On-Time Delay Cause Data* [Data set]. U.S. Department of Transportation.
