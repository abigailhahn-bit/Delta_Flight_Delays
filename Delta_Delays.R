# Analysis of Delta Flight Delays by Abigail Hahn 

# Load in packages
library(dplyr)
library(sf)
library(spdep)
library(ggplot2)
library(tidyr)
library(maps)
library(sp)

setwd("/Users/abigailhahn/Desktop/GIS_Project")


# Upload Delta delay cause csv and create data frame
delta_df <- read.csv("Airline_Delay_Cause.csv")

# View Data 
head(delta_df)
summary(delta_df)
glimpse(delta_df)


## Filter to remove any missing values, but retain 0s 
delta_df <- delta_df %>%
  filter(!is.na(airport))

exclude_codes <- c("ANC", "SJU", "OGG", "KOA", "JNU", "HNL", "LIH", "FAI", "STT", "STX")
delta_df <- delta_df %>%
  filter(!airport %in% exclude_codes) #remove airports not in contiguous US


delta_df <- delta_df %>%
  filter(airport != "ECP") #remove ECP airport data because it is not contained in coordinates data set

## Aggregate data to airport level- one row per airport, remove any N/A values in the columns
airport_summary <- delta_df %>% #This step sums all the data across the months so each airport is only represented once, but all the values are added
  group_by(airport) %>%
  summarise(
    total_delay_minutes = sum(arr_delay),
    total_flights = sum(arr_flights),
    avg_delay_per_flight = total_delay_minutes / total_flights,
    
    carrier_ct = sum(carrier_ct),
    weather_ct = sum(weather_ct),
    nas_ct = sum(nas_ct),
    security_ct = sum(security_ct),
    late_aircraft_ct = sum(late_aircraft_ct),
    
    carrier_delay = sum(carrier_delay),
    weather_delay = sum(weather_delay),
    nas_delay = sum(nas_delay),
    security_delay = sum(security_delay),
    late_aircraft_delay = sum(late_aircraft_delay)
  )

## Identify dominant delay cause 
# Select only the count columns
cause_counts <- airport_summary %>%
  select(carrier_ct, weather_ct, nas_ct, security_ct, late_aircraft_ct)

# Clean names to nice labels
names(cause_counts) <- c("carrier", "weather", "nas", "security", "late_aircraft")

# Add primary delay reason column
airport_summary$primary_delay_reason <- apply(cause_counts, 1, function(row) {
  names(row)[which.max(row)]
})

# Add coordinates for mapping purposes 
airport_coords <- read.csv("airports.csv")
head(airport_coords)

# Add lat and lon into delta_df 
delta_df <- delta_df %>%
  left_join(airport_coords %>%
              rename(airport = IATA, #rename column in delta_df so they match 
                     lat = LATITUDE,
                     lon = LONGITUDE),
            by = "airport")

# Convert to sf point geometry
delta_sf <- st_as_sf(delta_df, coords = c("lon", "lat"), crs = 4326)

# Reproject to a flat U.S. map (EPSG:9311)
delta_sf <- st_transform(delta_sf, 9311)

# Add average delay summary
delta_sf <- delta_sf %>%
  left_join(airport_summary, by = "airport")
# Convert to sp for Moran's I

delta_sp <- as(delta_sf, "Spatial")


# Create map of average flight delay in minutes by airport

states <- st_as_sf(map("state", plot = FALSE, fill = TRUE))
states <- states %>% 
  filter(!ID %in% c("alaska", "hawaii"))
states <- st_transform(states, 9311) #create states object for borders around states

png("Average_delay_per_flight.png", width = 6, height = 4, units = "in", res = 600)
ggplot() +
  geom_sf(data = states, fill = "white", color = "grey20") +
  geom_sf(data = delta_sf, aes(color = avg_delay_per_flight), size = 2.5) +
  scale_color_gradientn(
    colours = c("#1a9641", "#fdae61", "#f46d43", "#a50026"), #delay time is color-coordinated, HIGH delay(30 mins=red) LOW delay(0 mins=green)
    name = "Avg Delay"
  ) +
  coord_sf(datum = NA) +
  ggtitle("Average delay per flight (in minutes)") +
  theme_minimal()

dev.off()



# Create map of primary delay reason 

##color palette
reason_colors <- c(
  carrier = "#FF0090",
  weather = "#FFF700",
  nas = "#000FFF",
  security = "#ff7f00",
  late_aircraft = "#33a02c"
)

png("Primary_delay_cause.png", width = 6, height = 4, units = "in", res = 600)
ggplot() +
  geom_sf(data = states, fill = "white", color = "grey20") +
  geom_sf(data = delta_sf, aes(color = primary_delay_reason), size = 2.5) +
  scale_color_manual(values = reason_colors, name = "Primary Delay Cause") +
  coord_sf(datum = NA) +
  ggtitle("Primary Delay Cause by Airport") +
  theme_minimal()


dev.off()



# Morans's I
## Aggregate to one row per airport 
delta_airports_sf <- airport_summary %>%
  left_join(airport_coords %>%
              rename(airport = IATA,
                     lat = LATITUDE,
                     lon = LONGITUDE),
            by = "airport") %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(9311)

## convert to sp
delta_airports_sp <- as(delta_airports_sf, "Spatial")

## Get neighbors
coords <- coordinates(delta_airports_sp)
knn5 <- knearneigh(coords, k = 5)
nb5 <- knn2nb(knn5)

##Weighted matrix
weights5 <- nb2listw(nb5, style = "W")

## Moran's I
moran_result <- moran.test(delta_airports_sp$avg_delay_per_flight, weights5)
moran_result

#Interpretation: There is no statistically significant clustering of 
#airports with high average delays. Delay levels across U.S. airports 
#appear spatially random, rather than forming geographic hotspots.



# Local Moran's I
local_moran <- localmoran(delta_airports_sp$avg_delay_per_flight, weights5)
local_moran

delta_airports_sf$lisa_I <- local_moran[, 1]   # Ii values
delta_airports_sf$lisa_z <- local_moran[, 4]   # z-scores
delta_airports_sf$lisa_p <- local_moran[, 5]   # p-values

png("Local_morans_I.png", width = 6, height = 4, units = "in", res = 600)

ggplot() +
  geom_sf(data = states, fill = "white", color = "grey20") +
  geom_sf(data = delta_airports_sf, aes(color = lisa_z), size = 3) +
  scale_color_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0,
    name = "Local Moran's I (z-score)"
  ) +
  coord_sf(datum = NA) +
  ggtitle("Local Moran's I (LISA): Airport Delay Clusters") +
  theme_minimal()

dev.off()

# red (high) means high delay airport surrounded by high delay neighbors 
# blue (low) means low delay airport surrounded by high delay neighbors
# middle (white) means NO CLUSTERING 


# Map delays by month

monthly_delay <- delta_df %>% #
  group_by(year, month) %>%
  summarise(
    total_delay = sum(arr_delay, na.rm = TRUE),
    total_flights = sum(arr_flights, na.rm = TRUE),
    avg_delay = total_delay / total_flights
  ) %>%
  ungroup()

# graph graph graph 

png("Average_delay_by_month.png", width = 6, height = 4, units = "in", res = 600)

ggplot(monthly_delay, aes(x = interaction(year, month, lex.order = TRUE),
                          y = avg_delay, group = 1)) +
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(color = "darkred", size = 2) +
  labs(
    title = "Average Delay by Month",
    x = "Month",
    y = "Average Delay (minutes)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

dev.off()











