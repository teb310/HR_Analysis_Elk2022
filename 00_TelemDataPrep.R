#####################################################################################
# 00_TelemDataPrep.R
# script to prepare telemetry data for running home range analyses
# written by Joanna Burgar (Joanna.Burgar@gov.bc.ca) - 04-Oct-2019
#####################################################################################
.libPaths("C:/Program Files/R/R-4.2.0/library") # to ensure reading/writing libraries from C drive (H drive too slow)

# overall process: 
#- Upload Animal metadata and collar metadata (if applicable)
#- Upload shapefiles or csv of telemetry data
#- written for example of Barred Owl (BDOW) data
#- Output R object ready for home range analyses (MCP & KDE) 
#** MAKE SURE YOU'RE UPLOADING MOST RECENT METADATA FILES FROM "M:\WANSHARE\ESD\ESD_Shared\Region 2\Wildlife\Region 2 Wildlife Mgmt\Collar DATA & MANAGEMENT"

# run libraries
library(ggplot2)    # for plotting
library(dbplyr)     # for data manipulation
library(stringr)    # for formatting character data
library(lubridate)  # for date-time conversions
library(sf)         # for uploading shapefiles and working with sf objects
library(sp)         # for changing lat/long to UTM
library(rgdal)
library(tidyverse)

# set up working directories
InputDir <- c("C:/Users/TBRUSH/R/HR_Analysis_Elk2022/Input")
OutputDir <- c("C:/Users/TBRUSH/R/HR_Analysis_Elk2022/Output")
# GISDir <- c("H:/R/Analysis/Generic_HomeRange/GISDir")

##############################################################
#### METADATA EXPLORATION & FORMATTING (BEGINNING) 
#############################################################
## load data into R
setwd(InputDir)

###--- upload animal and collar metadata files
Elk_metadata <- read_csv("Capture and Telemetry_DATABASE_April 29_2022 (version 1).csv")
# select relevant records
anml.full <- Elk_metadata %>%
  mutate(CollarID = as.numeric(`Serial No.`)) %>%
  filter(Make == "Vectronics",
         Species == "Roosevelt elk",
         CollarID >= 22585)
anml.full <- anml.full %>%
  mutate(AnimalID = as.numeric(row.names(anml.full)),
         Cptr_Northing = as.numeric(`Northing (capture)`),
         Cptr_Easting = as.numeric(`Easting (capture)`),
         Species = as.factor(Species),
         Sex = as.factor(Sex))
anml.full <- anml.full %>%
  select(AnimalID,
         CollarID,
         Species, 
         Sex, 
         Age_Class = `Age Class`, 
         Comments, 
         Cptr_EPU = `Population Unit`,
         Cptr_Northing,
         Cptr_Easting,
         Cptr_UTM = `UTM Zone (capture)`,
         Cptr_Date = Date, 
         Cptr_Time = Time, 
         Rls_Date = `Release Date`, 
         Rls_Time = `Release Time`,
         Rls_EPU = `Population Unit (release)`,
         Cptr_Method = `Capture Method`, 
         Drug = `Immobilization Drug`, 
         Volume = Volume...43, 
         `Tick Hair Loss`:Teeth)

glimpse(anml.full) # view data
head(anml.full)

# change lat&longs to UTM
xy <- anml.full %>%
  select(AnimalID, Cptr_UTM, Long = Cptr_Northing, Lat = Cptr_Easting) %>%
  filter(Cptr_UTM == "Lat Long")
coordinates(xy) <- c("Long", "Lat")
proj4string(xy) <- CRS("+proj=longlat +datum=WGS84")
res <- spTransform(xy, CRS("+proj=utm +zone=10 ellps=WGS84"))
new_coord <- as.data.frame(res)

anml.coord <- full_join(anml.full, new_coord, by=c("AnimalID", "Cptr_UTM"))%>%
  mutate(Cptr_UTM = 10,
         Cptr_Northing = if_else(is.na(Lat), Cptr_Northing, Lat),
         Cptr_Easting = if_else(is.na(Long), round(Cptr_Easting, 0), round(Long, 0))) %>%
  select(AnimalID:Teeth)

anml.full <- anml.coord


##### subset to smaller dataframe, and rename columns for consistency
names(anml.full)
anml <- anml.full%>%
  select("AnimalID","Species","Sex", "Age_Class","Cptr_Northing","Cptr_Easting", "Cptr_Date","Rls_Date")
head(anml)  # check

# fix age classification
anml$Age_Class <- as.factor(case_when(
  grepl("A", anml$Age_Class) ~ "A",
  grepl("Y", anml$Age_Class) ~ "Y",
  TRUE ~ anml$Age_Class
))

# format dates for R
anml$Cptr_Datep <- as.POSIXct(strptime(anml$Cptr_Date, format = "%d-%b-%y"))
anml$Rls_Datep <- as.POSIXct(strptime(anml$Rls_Date, format = "%d-%b-%y"))

# add in Year
anml$Cptr_Year <- year(anml$Cptr_Datep)

glimpse(anml) # check dates
summary(anml) # check for NAs

###--- Check  data for number of captures per year by species, sex and min/max annual capture dates
anml %>% group_by(Cptr_Year, Species) %>% count(Sex)
anml %>% group_by(Cptr_Year, Species) %>% summarise(min(Cptr_Datep), max(Cptr_Datep))

###--- to turn the capture points into spatial object, using the CRS for NAD83 UTM Zone 10
# may need to clean some data during the import
# in this example, issue with one of the coordinates, delete that row from df before converting to sf object
Cpt.sf <- st_as_sf(anml, coords=c("Cptr_Easting","Cptr_Northing"), crs=26910)

# plot to check
ggplot() +
  geom_sf(data = Cpt.sf, aes(fill=Species, col=Species)) +
  coord_sf() +
  theme_minimal()

ggplot() +
  geom_sf(data = Cpt.sf, aes(fill=as.factor(Cptr_Year), col=as.factor(Cptr_Year))) +
  coord_sf() +
  theme_minimal()

ggplot() +
  geom_sf(data = Cpt.sf, aes(fill=Sex, col=Sex)) +
  coord_sf() +
  theme_minimal()

##############################################################
#### METADATA EXPLORATION & FORMATTING (END) 
#############################################################

##############################################################
#### TELEMETRY DATA EXPLORATION & FORMATTING (BEGINNING) 
#############################################################

#############################################################
###--- For shapefiles
# setwd(GISDir) # point to where shapefiles are housed
# list.files(GISDir, pattern='\\.shp$', recursive = TRUE)
# will list all shapefiles in the folder and sub-folders
# necessary for uploading individual shapefiles as need pathway (dsn) and shapefile name (layer)

# Load in shapefiles - change the name to something useful, pertaining to the animal/collar
# example below is if shapefile is in GISDir and shapefile is called BDOW01
# use the %>% section of the code to simplify shapefile to only pertininent columns

# shp1 <- st_read(dsn = "./", layer = "BDOW01") %>% select(SymbolID, BeginTime) 


###--- For csv upload
setwd(InputDir)
telem <- read_csv("Position-2022-Jun-07_15-19-55.csv", 
                  col_types = cols(`Acq. Time [LMT]` = col_datetime(format = "%Y-%m-%d %H:%M:%S")))
glimpse(telem) # check columns are coming in as appropriate class
telem$`Mortality Status` <- as.factor(telem$`Mortality Status`)
telem$CollarID <- telem$`Collar ID`
head(telem) # check that data is reading correctly
summary(telem) # check if spelling inconsistencies or NAs


# delete all records in UTM zone 33 (Germany)
telem <- telem[telem$Zone != 33,]

# format date
telem <- telem %>%
  separate(`Acq. Time [LMT]`, c("Date", "Time"), sep = " ")
telem$Date <- as.POSIXct(strptime(telem$Date, "%Y-%m-%d"))

# add animalID field
anml.dat <- anml.full %>%
  mutate(Cptr_Date = as.POSIXct(strptime(Cptr_Date, format = "%d-%b-%y")),
         AnimalID = as.integer(AnimalID)) %>%
  select(AnimalID, CollarID, Cptr_Date)
telem.tmp <- full_join(telem, anml.dat, by="CollarID") %>%
  # only include records after capture
  filter(Date >= (Cptr_Date+1))
  # sort out duplicate entries
telem.dup <- telem.tmp %>% select(Date:CollarID) %>% duplicated(fromLast = TRUE) %>% as.data.frame()
colnames(telem.dup) <- "Duplicated"
telem.dup <- bind_cols(telem.tmp, telem.dup)
telem.dup <- telem.dup %>%
  filter(Duplicated == F)

# get rid of entries port-mortality
telem.mort <- telem.dup %>%
  group_by(AnimalID) %>%
  filter(`Mortality Status` == "Mortality No Radius") %>%
  arrange(Date, ) %>%
  slice_head() %>%
  select(AnimalID, Mort_Date = Date)

telem.new <- full_join(telem.dup, telem.mort, by="AnimalID") %>%
  mutate(Mort_Date = if_else(is.na(Mort_Date), as.POSIXct(Sys.Date()), Mort_Date)) %>%
  filter(Date < Mort_Date)
summary(telem.new)

# If all looks good, add in geometry
# use the CRS for lat/long and WGS84
telem.sf <- st_as_sf(telem.new[telem.new$`Latitude[deg]`<90,], coords=c("Longitude[deg]","Latitude[deg]"), crs=4326) %>%  
  select(AnimalID, CollarID, Date, Time, geometry)

# create new Group names - revise as appropriate
# telem.sf$Group.New <- as.factor(ifelse(grepl("Captive", telem.sf$Group),"Captive",
#                                        ifelse(grepl("Relocated", telem.sf$Group), "Relocated",
#                                               ifelse(grepl("Control", telem.sf$Group), "Control",
#                                                      ifelse(grepl("Resident", telem.sf$Group), "Resident", NA)))))
# 
# table(telem.sf$Group, telem.sf$Group.New) # check that grouping worked

# format dates for R
telem.sf$Date.Time <- paste(telem.sf$Date, telem.sf$Time, sep=" ")
telem.sf$Date.Timep <- as.POSIXct(strptime(telem.sf$Date.Time, format = "%Y-%m-%d %H:%M:%S"))
telem.sf$Year <- year(telem.sf$Date.Timep)
telem.sf$Month <- month(telem.sf$Date.Timep)
telem.sf$Day.j <- round(as.numeric(julian(telem.sf$Date.Timep)), 0) # Julian day

glimpse(telem.sf)
summary(telem.sf)

# plot to check
ggplot() +
  geom_sf(data = telem.sf) +
  coord_sf() +
  theme_minimal()

ggplot() +
  geom_sf(data = telem.sf, aes(fill=as.factor(Year), col=as.factor(Year))) +
  coord_sf() +
  theme_minimal()

ggplot() +
  geom_sf(data = telem.sf, aes(fill=AnimalID, col=AnimalID)) +
  facet_wrap(~Year) +
  theme(legend.position = "bottom") +
  coord_sf() 

# looks good - all plotting in general area

###--- Create Season (breeding) dates
# check date range by year for telemetry data
telem.sf %>% st_drop_geometry() %>% group_by(Year) %>% summarise(Min = min(Date.Timep), Max = max(Date.Timep))
# Year Min                 Max                
# <dbl> <dttm>              <dttm>             
#   1  2017 2017-01-25 14:00:37 2017-12-31 16:03:00
# 2  2018 2018-01-01 03:00:37 2018-12-31 23:02:30
# 3  2019 2019-01-01 10:00:37 2019-12-31 19:01:32
# 4  2020 2020-01-01 06:00:37 2020-12-31 13:02:08
# 5  2021 2021-01-01 00:00:37 2021-12-31 20:03:00
# 6  2022 2022-01-01 07:00:37 2022-06-07 20:00:44

# Breeding = Apr 1 to Sep 30; Non-Breeding = Oct 1 - Mar 30
# telem.sf$Season <-as.factor(ifelse(telem.sf$Month < 4 | telem.sf$Month > 9, "Non-Breeding",
#                                  ifelse(telem.sf$Month > 3 | telem.sf$Month < 10, "Breeding", NA)))

# Winter = Dec 1 to Mar 31; Non-winter = Apr 1 to Nov 30
telem.sf$Season <-as.factor(ifelse(telem.sf$Month < 4 | telem.sf$Month > 11, "Winter",
                                   ifelse(telem.sf$Month > 3 | telem.sf$Month < 12, "Non-winter", NA)))
                                   

table(telem.sf$Month, telem.sf$Season) # check to make sure Seasons are pulling correct dates
# pulling dates correctly, note that telemetry data is minimal in non-breeding season

###--- check number of fixes per animal / day / etc
# Check the multiple counts of animals per day
counts.per.day <- telem.sf %>% 
  st_drop_geometry() %>%
  group_by(AnimalID, Day.j) %>% 
  summarize(total = n(), unique = unique(Day.j)) %>% 
  group_by(AnimalID, total) %>% 
  summarise(total.j = n()) 
  
# Only select first fix per animal per day
telem.1fix <- telem.sf %>%
  group_by(AnimalID, Day.j) %>%
  slice_min(Date.Timep)

# redo
counts.per.day1 <- telem.1fix %>% 
  st_drop_geometry() %>%
  group_by(AnimalID, Day.j) %>% 
  summarize(total = n(), unique = unique(Day.j)) %>% 
  group_by(AnimalID, total) %>% 
  summarise(total.j = n())

pp = ggplot(data = counts.per.day, aes(total,total.j,col=AnimalID)) + 
  geom_point() + 
  ggtitle('Number of fixes per julien day per animal'); pp 
# if want only 1 fix per day
# telem.sf <- telem.1fix

## Q : How many fixes do we have per animal?
p1 <- ggplot(telem.sf) + 
  geom_bar(aes(AnimalID)) + 
  theme(axis.text.x = element_text(angle = 60, hjust = 1)) +
  facet_wrap(~Year, ncol=1)  ; p1

unique(telem.sf$AnimalID) # 104 animals
table(telem.sf$AnimalID, telem.sf$Year) # 5 with data for all 6 years

## Q:  What about temporal variability - number of years? time of year? 
id.date <- telem.sf %>% st_drop_geometry() %>% group_by(AnimalID, Year, Month) %>% summarise(count = n()) ; id.date
id.season.yr <- telem.sf %>% st_drop_geometry() %>% group_by(AnimalID, Year, Season) %>% summarise(count = n()) ; id.season.yr
id.season <- telem.sf %>% st_drop_geometry() %>% group_by(AnimalID, Season) %>% summarise(count = n()) ; id.season
id.jdate <- telem.sf %>% st_drop_geometry() %>% group_by(AnimalID, Year) %>% summarise(count = length(unique(Day.j))) ; id.jdate 


p2 <- ggplot(id.date,aes(x = as.factor(Year), count)) + 
  geom_bar(stat ="identity") + 
  facet_wrap(~AnimalID) + 
  ggtitle("Total telemetry fixes per animal per year (all months)"); p2

p2.1 <- ggplot(id.jdate, aes(x = as.factor(Year), count)) + 
  geom_bar(stat ="identity") +  
  geom_hline(yintercept=50, linetype="dashed", color = "red") +
  facet_wrap(~AnimalID) + 
  ggtitle("Total telemetry days per animal per year (all months)"); p2.1

p3 <- ggplot(id.date,aes(x = as.factor(Month), count)) + 
  geom_bar(stat ="identity") + 
  facet_wrap(~AnimalID)+ 
  ggtitle("Total telemetry fixes per animal per month (all years)"); p3

p4 <- ggplot(id.season,aes(x = Season, count)) + 
  geom_bar(stat ="identity") +  
  geom_hline(yintercept=50, linetype="dashed", color = "red") +
  facet_wrap(~AnimalID) + 
  theme(axis.text.x = element_text(angle = 90)) + 
  ggtitle("Total telemetry fixes per animal per season "); p4 # red line to highlight above/below 50 fixes


# Q how much data do we have when we combine all years and all animals? 
p5 <- ggplot(id.date,aes(x = Month, count)) + 
  geom_bar(stat ="identity"); p5
p6 <- ggplot(id.season,aes(x = Season,count)) + 
  geom_bar(stat ="identity"); p6
p7 <- ggplot(id.jdate,aes(x = as.factor(Year), count)) + 
  geom_bar(stat ="identity"); p7

##############################################################
#### TELEMETRY DATA EXPLORATION & FORMATTING (END) 
#############################################################

##############################################################
#### MERGE INTO ONE (FULL) SF OBJECT (BEGINNING)
#############################################################
head(anml)
head(telem.sf)

HR.sf <- left_join(telem.sf %>% select(AnimalID, Date.Timep, Year, Month, Day.j, Season),
                   anml %>% select(-Cptr_Date, -Rls_Date), by = "AnimalID")

glimpse(HR.sf)
summary(HR.sf)

# drop levels if no entries
HR.sf$Species <- droplevels(HR.sf$Species)
HR.sf$Sex <- droplevels(HR.sf$Sex)
HR.sf$Age_Class <- droplevels(HR.sf$Age_Class)

summary(HR.sf) # check drop levels - looks good

# plot to check
ggplot() +
  geom_sf(data = HR.sf, aes(fill=Sex, col=Sex))
  
ggplot() +
  geom_sf(data = HR.sf, aes(fill=as.factor(Cptr_Year), col=as.factor(Cptr_Year)))


HR.df <- HR.sf %>% st_drop_geometry() # create non-spatial attribute table for joining
##############################################################
#### MERGE INTO ONE (FULL) SF OBJECT (END)
#############################################################

######################################################################
#### SUBSET DATA TO ANIMAL_SEASON AND ANIMAL_YEAR MIN OBS (BEGINNING) 
#####################################################################
# need to drop animals with less than minimum number of observations
summary(HR.sf)
table(HR.sf$Year, HR.sf$Season)
# Breeding Non-Breeding
# 2017     1697          931
# 2018     3214         2430
# 2019     4036         3459
# 2020     6497         5274
# 2021    10616         8717
# 2022     4595         5013

###--- Calculate MCPs for each animal, annually and seasonally (i.e.,combining years but separating seasons)
# group into seasons for each animal 
HR.sf$Animal_Season <- as.factor(paste(HR.sf$AnimalID, HR.sf$Season, sep="_"))
HR.sf$Animal_Year <- as.factor(paste(HR.sf$AnimalID, as.factor(HR.sf$Year), sep="_"))

as.data.frame(HR.sf %>% group_by(AnimalID) %>% count(Season, sort=TRUE)) 
# 206 unique animal-seasons but only 189 with >= 50 obs, 194 with >= 25 obs
as.data.frame(HR.sf %>% group_by(AnimalID) %>% count(Year, sort=TRUE))
# 281 unique animal-years but only 271 with >= 50 obs, 272 with >= 25 obs

###--- DECISION POINT - how many obs minimum for HR estimate?
# remove animals with < 50 points per Animal_Season
head(HR.sf)
HR.sf.AS <- HR.sf
HR.sf.AS <- HR.sf.AS[HR.sf.AS$Animal_Season %in% names(table(HR.sf.AS$Animal_Season)) [table(HR.sf.AS$Animal_Season) >= 50], ]
HR.sf.AS$Animal_Season <- droplevels(HR.sf.AS$Animal_Season)
nrow(HR.sf) - nrow(HR.sf.AS) # dropped 504 points out of 56,479

# remove animals with < 50 points per Animal_Year
HR.sf.AY <- HR.sf
HR.sf.AY <- HR.sf.AY[HR.sf.AY$Animal_Year %in% names(table(HR.sf.AY$Animal_Year)) [table(HR.sf.AY$Animal_Year) >= 50], ]
HR.sf.AY$Animal_Year <- droplevels(HR.sf.AY$Animal_Year)
nrow(HR.sf) - nrow(HR.sf.AY) # dropped 229 points of 56,479

as.data.frame(HR.sf.AS %>% group_by(AnimalID) %>% count(Season, sort=TRUE)) # 0 animal-seasons below 50 obs; 183 unique animal-seasons
as.data.frame(HR.sf.AY %>% group_by(AnimalID) %>% count(Year, sort=TRUE)) # 0 animal-years below 50 obs; 271 unique animal-years

# update HR.df
HR.df <- HR.sf %>% st_drop_geometry()

######################################################################
#### SUBSET DATA TO ANIMAL_SEASON AND ANIMAL_YEAR MIN OBS (END) 
#####################################################################

##############################################################
#### HOUSEKEEPING (BEGINNING)
#############################################################

###-- Save workspace and move to home range analysis - 01_MCP.R
setwd(InputDir)
save.image("00_TelemDataPrep.RData")
# load("00_TelemDataPrep.RData")

###--- For housekeeping, remove all but necessary objects to use in next script
rm(list=setdiff(ls(), c("telem.sf","HR.sf", "HR.df","anml", "Cpt.sf", "HR.sf.AS", "HR.sf.AY")))
save.image("HR_InputData.RData")

##############################################################
#### HOUSEKEEPING (END)
#############################################################

