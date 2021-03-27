.libPaths("/home/alber.ipia/R/x86_64-pc-linux-gnu-library/4.0")
source("~/Documents/bdc_access_key.R")
access_key <- Sys.getenv("BDC_ACCESS_KEY")
stopifnot(access_key != "")

library(sits)

# NOTE: Original local cube producing error.
# data_cube <- sits::sits_cube(source = "LOCAL",
#                              name = "pantanal",
#                              satellite = "LANDSAT-8",
#                              sensor = "OLI",
#                              band = c("NDVI", "B1", "B2", "B3", "B4",
#                                       "B5", "B6", "B7", "EVI", "FMASK"),
#                              data_dir = "./data/cube/LC8_30_16D_STK-1_041051_2018-01-01_2018-12-31",
#                              parse_info = c("mission", "sp_resolution",
#                                             "time_resolution", "type",
#                                             "version", "tile", "date",
#                                             "end_date", "band"),
#                              delim = "_")

data_cube <- sits::sits_cube(source = "BDC",
                             name = "pantanal",
                             collection = "LC8_30_16D_STK-1",
                             bands = c("NDVI", "B1", "B2", "B3", "B4",
                                       "B5", "B6", "B7", "EVI"),
                             tiles = c("041051", "041052"),
                             start_date = "2018-01-10",
                             end_date   = "2018-12-19")

samples_tb <- sits::sits_get_data(cube = data_cube,
                                  file = "./reproduce_error/samples.csv")

# NOTE: The error happens here!
ml_model <- sits::sits_train(samples_tb,
                             ml_method = sits::sits_rfor(trees = 2000))

probs <- sits::sits_classify(data_cube,
                             ml_model = ml_model,
                             memsize = 40,
                             multicores = 20,
                             output_dir = "./reproduce_error")

probs <- dplyr::mutate(probs,
                       processing = tibble::tibble(start_time = start_time,
                                                   end_time = Sys.time()))
