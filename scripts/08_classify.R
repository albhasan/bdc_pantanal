.libPaths("/home/alber.ipia/R/x86_64-pc-linux-gnu-library/4.0")

library(sits)
library(dplyr)

#
# Processing 1276 block(s)
# System has not been booted with systemd as init system (PID 1). Can't operate.
# Failed to create bus connection: Host is down
# Starting classification at 2021-03-25 14:03:06
#  Progress: ─────────                                                                                                   100%Error in unserialize(node$con) :
#   Failed to retrieve the value of ClusterFuture (<none>) from cluster RichSOCKnode #2 (PID 420 on localhost ‘localhost’). The reason reported was ‘error reading from connection’. Post-mortem diagnostic: No process exists with this PID, i.e. the localhost worker is no longer alive.
# Calls: sourceWithProgress ... resolved -> resolved.ClusterFuture -> receiveMessageFromWorker
# In addition: Warning message:
# In system("timedatectl", intern = TRUE) :
#   running command 'timedatectl' had status 1
# Execution halted

# Using 160 blocks of size 46 x 11204
# Progress: ────────────                                                                                         100%Error in unserialize(node$con) :
#     Failed to retrieve the value of MultisessionFuture (<none>) from cluster RichSOCKnode #18 (PID 10718 on localhost ‘localhost’). The reason reported was ‘error reading from connection’. Post-mortem diagnostic: No process exists with this PID, i.e. the localhost worker is no longer alive.
# Calls: sourceWithProgress ... resolved -> resolved.ClusterFuture -> receiveMessageFromWorker
# Execution halted




#---- Configuration ----

## Level model (this is for the BIOME)
classification_name <- "second_classification"
my_bands            <- c("NDVI", "B1", "B2", "B3", "B4",
                         "B5", "B6", "B7", "EVI", "FMASK")

## Level data (for list of tiles in the BIOME)
project_dir   <- "/home/alber.ipia/Documents/bdc_pantanal"
parse_info    <- c("mission", "sp_resolution",
                   "time_resolution", "type",
                   "version", "tile", "date",
                   "end_date", "band")
out_dir <- paste0(project_dir, "/results/", classification_name)

cube_names <- c("LC8_30_16D_STK-1_041051_2018-01-01_2018-12-31",
                 "LC8_30_16D_STK-1_041052_2018-01-01_2018-12-31")

model_file    <- "/home/alber.ipia/Documents/bdc_pantanal/results/second_classification/ml_model.rds"

stopifnot(file.exists(model_file))
stopifnot(dir.exists(out_dir))



#---- Classify ----

ml_model <- readRDS(model_file)

for (cube_name in cube_names) {
    start_time <- Sys.time()
    data_cube <- sits::sits_cube(source = "LOCAL",
                                 name = cube_name,
                                 satellite = "LANDSAT-8",
                                 sensor = "OLI",
                                 band = my_bands,
                                 data_dir = file.path(project_dir, "data",
                                                      "cube", cube_name),
                                 parse_info = parse_info,
                                 delim = "_")
    probs <- sits::sits_classify(data_cube,
                                 ml_model = ml_model,
                                 memsize = 4,
                                 multicores = 5,
                                 output_dir = out_dir)
    probs <- dplyr::mutate(probs,
                           processing = tibble::tibble(start_time = start_time,
                                                       end_time = Sys.time()))
    saveRDS(probs, file = file.path(out_dir, paste0(cube_name, "_results.rds")))
}
