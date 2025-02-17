#####################################################################################
# 01_MCP.R
# script to run MCPs
# following from 00_TelemDataPrep.R
# adapted from script written by genevieve perkins (genevieve.perkins@gov.bc.ca)
# modified by Joanna Burgar (Joanna.Burgar@gov.bc.ca) - 06-Oct-2019 and Tristen Brush (tristen.brush@gov.bc.ca) - July 2022
#####################################################################################
.libPaths("C:/Program Files/R/R-4.2.0/library") # to ensure reading/writing libraries from C drive (H drive too slow)

# overall process: 
#- Define the area of interest per animal; availability/ vs use (MCP)
#- Export MCP shapefiles

# help files: 
#https://cran.r-project.org/web/packages/adehabitatHS/adehabitatHS.pdf

# run libraries
library(bcmaps)
library(adehabitatHR)
library(dplyr)
library(ggplot2)
library(Cairo)
library(sf)
library(sp)


# set up working directories
InputDir <- c("C:/Users/TBRUSH/R/HR_Analysis_Elk2022/Input")
OutputDir <- c("C:/Users/TBRUSH/R/HR_Analysis_Elk2022/Output")
GISDir <- c("H:/ArcGIS/HR_Analysis_Elk2022")

##############################################################
#### LOAD and REVIEW DATA (BEGINNING)
#############################################################
## load data into R
setwd(InputDir)
load("HR_InputData.RData")

# review spatial object data - check to see if loaded properly
st_geometry(HR.sf) # currently in WGS84 CRS, lat/long
HR.sf$AnimalID <- as.factor(HR.sf$AnimalID)
names(HR.sf)
summary(HR.sf)

# plot to check
# check the spread of elk with mapped locations 
bc <- bc_bound()
SC <- nr_districts() %>% filter(ORG_UNIT %in% c("DCK", "DSQ", "DSC"))

# Plot by AnimalID (104 individuals)
unique(HR.sf$AnimalID)
ggplot() +
  geom_sf(data=SC, fill="white", col="gray") +
  geom_sf(data=HR.sf, aes(fill=AnimalID, col=AnimalID))+
  coord_sf() +
  theme_minimal() +
  ggtitle("Animal GPS locations")


# Plot by Animal_Season (189 animal_seasons)
unique(HR.sf.AS$Animal_Season)
ggplot() +
  geom_sf(data=SC, fill="white", col="gray") +
  geom_sf(data=HR.sf.AS, aes(fill=Animal_Season, col=Animal_Season), show.legend = FALSE)+
  facet_wrap(vars(Season)) +
  coord_sf() +
  theme_minimal() +
  ggtitle("Animal_Season GPS locations")

# Plot by season
unique(HR.sf$Season)
ggplot() +
  geom_sf(data=SC, fill="white", col="gray") +
  geom_sf(data=HR.sf, aes(fill=Season, col=Season)) +
  coord_sf() +
  theme_minimal() +
  ggtitle("Seasonal GPS locations")


# Plot by Animal_Year (271 individuals)
unique(HR.sf.AY$Animal_Year)
ggplot() +
  geom_sf(data=SC, fill="white", col="gray") +
  geom_sf(data=HR.sf.AY, aes(fill=Animal_Year, col=Animal_Year), show.legend = FALSE)+
  facet_wrap(vars(Year)) +
  coord_sf() +
  theme_minimal() +
  ggtitle("Animal_Year GPS locations")

# Plot by year
unique(HR.sf$Year)
ggplot() +
  geom_sf(data=SC, fill="white", col="gray") +
  geom_sf(data=HR.sf, aes(fill=Year, col=Year))+
  facet_wrap(vars(Year)) +
  coord_sf() +
  theme_minimal() +
  ggtitle("Yearly GPS locations")

##############################################################
#### LOAD and REVIEW DATA (END)
#############################################################

##############################################################
#### RUN MINIMUM CONVEX POLYGON - ANIMAL_SEASON (BEGINNING)
#############################################################

###--- Change to a SpatialPointsDataFrame and set to utm (m units)
HR.sf.AS_utm <- st_transform(HR.sf.AS, crs=26910) # utm and m units

HR.sf.AS_utm$geometry
HR.sp.AS <- as(HR.sf.AS_utm, "Spatial")
class(HR.sp.AS)

# Calculate MCPs for each animal season
names(HR.sp.AS)
ASmcp.95 <- mcp(HR.sp.AS[,c("Animal_Season")], percent = 95)
ASmcp.50 <- mcp(HR.sp.AS[,c("Animal_Season")], percent = 50)

# Plot
plot(HR.sp.AS) # looks similar to before
plot(ASmcp.95, col = alpha(1:73, 0.5), add = TRUE)
plot(ASmcp.50, col = alpha(1:73, 0.5), add = TRUE)

# create shapefiles
# add in meta data covariates
head(HR.df)

ASmcp.95.sf <- st_as_sf(ASmcp.95)
colnames(ASmcp.95.sf)[1] <- "Animal_Season" # change id back to Animal_Season
ASmcp.95.sf <- dplyr::left_join(ASmcp.95.sf, 
                                HR.df[c("Animal_Season","AnimalID","Season","Species","Sex", "Age_Class")], 
                                by = "Animal_Season") 
ASmcp.95.sf$HR_Type <- "MCP_95"

ASmcp.50.sf <- st_as_sf(ASmcp.50)
colnames(ASmcp.50.sf)[1] <- "Animal_Season" # change id back to Animal_Season
ASmcp.50.sf <- dplyr::left_join(ASmcp.50.sf, 
                                HR.df[c("Animal_Season","AnimalID","Season","Species","Sex", "Age_Class")], 
                                by = "Animal_Season") 
ASmcp.50.sf$HR_Type <- "MCP_50"


# combine and write as one shapefile
setwd(GISDir)

ASmcp.sf <- rbind(ASmcp.50.sf,ASmcp.95.sf)
st_write(ASmcp.sf, "MCP_Animal_Season.shp", append = FALSE)
# write to csv too
setwd(OutputDir)
ASmcp.50 <- st_drop_geometry(ASmcp.50.sf[!duplicated(ASmcp.50.sf$Animal_Season), ])
ASmcp.95 <- st_drop_geometry(ASmcp.95.sf[!duplicated(ASmcp.95.sf$Animal_Season), ])
ASmcp <- rbind(ASmcp.50,ASmcp.95)
write.csv(ASmcp, file = "MCP_Animal_Season.csv", row.names = FALSE)


###---
# Calculate the MCP by including 50 to 100 percent of points
par(mar=c(1,1,1,1)) # to fit in window
AS.hrs <- mcp.area(HR.sp.AS[c("Animal_Season")], percent = seq(50, 100, by = 10))
# visual inspection shows much variation in animals use of home range between 50-100% of points
AS.hrs # examine dataframe
AS.hrs.df <- as.data.frame(AS.hrs)
# setwd(OutputDir)
# write.csv(AS.hrs.df, "MCP_HRS_Animal_Season.csv")

##############################################################
#### RUN MINIMUM CONVEX POLYGON - ANIMAL_SEASON (END)
#############################################################


##############################################################
#### RUN MINIMUM CONVEX POLYGON - ANIMAL_YEAR (BEGINNING)
#############################################################

###--- Change to a SpatialPointsDataFrame and set to utm (m units)
HR.sf.AY_utm <- st_transform(HR.sf.AY, crs=26910) # utm and m units

HR.sf.AY_utm$geometry
HR.sp.AY <- as(HR.sf.AY_utm, "Spatial")
class(HR.sp.AY)

# Calculate MCPs for each animal season
names(HR.sp.AY)
AYmcp.95 <- mcp(HR.sp.AY[,c("Animal_Year")], percent = 95)
AYmcp.50 <- mcp(HR.sp.AY[,c("Animal_Year")], percent = 50)

# Plot
plot(HR.sp.AY) # looks similar to before
plot(AYmcp.95, col = alpha(1:73, 0.5), add = TRUE)
plot(AYmcp.50, col = alpha(1:73, 0.5), add = TRUE)

# create shapefiles
# add in meta data covariates
head(HR.df)

AYmcp.95.sf <- st_as_sf(AYmcp.95)
colnames(AYmcp.95.sf)[1] <- "Animal_Year" # change id back to Animal_Year
AYmcp.95.sf <- dplyr::left_join(AYmcp.95.sf, 
                                HR.df[c("Animal_Year","AnimalID","Year","Species","Sex", "Age_Class")], 
                                by = "Animal_Year") 
AYmcp.95.sf$HR_Type <- "MCP_95"

AYmcp.50.sf <- st_as_sf(AYmcp.50)
colnames(AYmcp.50.sf)[1] <- "Animal_Year" # change id back to Animal_Year
AYmcp.50.sf <- dplyr::left_join(AYmcp.50.sf, 
                                HR.df[c("Animal_Year","AnimalID","Year","Species","Sex", "Age_Class")], 
                                by = "Animal_Year") 
AYmcp.50.sf$HR_Type <- "MCP_50"


# combine and write as one shapefile
setwd(GISDir)
AYmcp.sf <- rbind(AYmcp.50.sf,AYmcp.95.sf)
st_write(AYmcp.sf, "MCP_Animal_Year.shp", append = FALSE)

# write to csv too
setwd(OutputDir)
AYmcp.50 <- st_drop_geometry(AYmcp.50.sf[!duplicated(AYmcp.50.sf$Animal_Year), ])
AYmcp.95 <- st_drop_geometry(AYmcp.95.sf[!duplicated(AYmcp.95.sf$Animal_Year), ])
AYmcp <- rbind(AYmcp.50,AYmcp.95) 
write.csv(AYmcp, file = "MCP_Animal_Year.csv", row.names = FALSE)

###---
# Calculate the MCP by including 50 to 100 percent of points
par(mar=c(1,1,1,1)) # to fit in window
AY.hrs <- mcp.area(HR.sp.AY[c("Animal_Year")], percent = seq(50, 100, by = 10))
# visual inspection shows much variation in animals use of home range between 50-100% of points
AY.hrs # examine dataframe
AY.hrs.df <- as.data.frame(AY.hrs)
# setwd(OutputDir)
# write.csv(AY.hrs.df, "MCP_HRS_Animal_Year.csv")

##############################################################
#### RUN MINIMUM CONVEX POLYGON - ANIMAL_YEAR (END)
#############################################################


##############################################################
#### SUMMARISE MINIMUM CONVEX POLYGON ESTIMATES (BEGINNING)
#############################################################

###--- summarise data

# Animal Year by Group Type
AYmcp.sf %>% group_by(HR_Type, Year) %>% 
  summarise(mean = mean(area), se = sd(area)/sqrt(n())) %>% st_drop_geometry()

# HR_Type  Year  mean    se
# 1 MCP_50   2017  670.  9.55
# 2 MCP_50   2018 1305. 10.9 
# 3 MCP_50   2019 1269.  7.79
# 4 MCP_50   2020 1198.  8.51
# 5 MCP_50   2021 1248.  7.11
# 6 MCP_50   2022  591.  5.48
# 7 MCP_95   2017 2835. 27.0 
# 8 MCP_95   2018 4027. 28.3 
# 9 MCP_95   2019 4217. 30.7 
# 10 MCP_95   2020 3886. 22.3 
# 11 MCP_95   2021 3792. 15.0 
# 12 MCP_95   2022 1996. 15.4 

# plot out the MCP area sensitivty by year and group type
setwd(OutputDir)
AY.mcp.sens <- ggplot(AYmcp.sf, aes(x=as.factor(Year), y=area, color=HR_Type)) +
  geom_boxplot() +
  scale_color_brewer(palette="Dark2") +
  labs(title="MCP Area Sensitivity", y = "MCP Area (ha)")+
  theme(axis.title.x=element_blank())
  # facet_wrap(.~Group.New, scales="free_y")

# Cairo(800, 500, pointsize = 36,
#       file="MCP_Year_Group.png", type="png", bg="white")
# AY.mcp.sens
# dev.off()

# Animal season by Group Type
ASmcp.sf %>% group_by(HR_Type, Season) %>% 
  summarise(mean = mean(area), se = sd(area)/sqrt(n())) %>% st_drop_geometry()

# HR_Type Season         mean    se
# 1 MCP_50  Breeding     1109.  4.73
# 2 MCP_50  Non-Breeding 1164.  6.85
# 3 MCP_95  Breeding     4221.  13.2 
# 4 MCP_95  Non-Breeding 4230.  18.9 

# plot out the MCP area sensitivty by year and group type
setwd(OutputDir)
AS.mcp.sens <- ggplot(ASmcp.sf, aes(x=Season, y=area, color=HR_Type)) +
  geom_boxplot() +
  scale_color_brewer(palette="Dark2") +
  labs(title="MCP Area Sensitivity", y = "MCP Area (ha)")+
  theme(axis.title.x=element_blank())
  # facet_wrap(.~Group.New, scales="free_y")

Cairo(800, 500, pointsize = 36,
      file="MCP_Season_Winter.png", type="png", bg="white")
AS.mcp.sens
dev.off()

##############################################################
#### SUMMARISE MINIMUM CONVEX POLYGON ESTIMATES (END)
#############################################################


##############################################################
#### HOUSEKEEPING (BEGINNING)
#############################################################

###-- Save workspace and move to KDE home range analysis - 02_KDE.R
setwd(InputDir)
save.image("01_MCP.RData")

##############################################################
#### HOUSEKEEPING (END)
#############################################################


