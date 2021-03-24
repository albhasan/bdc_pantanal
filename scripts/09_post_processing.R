.libPaths("/home/alber.ipia/R/x86_64-pc-linux-gnu-library/4.0")

library(sits)
library(dplyr)



#---- set up level classification ----

# ## Level model (this is for the BIOME)
classification_name <- "first_classification"
my_bands            <- c("NDVI", "B1", "B2", "B3", "B4",
                         "B5", "B6", "B7", "EVI", "FMASK")
#
# ## Level data (for list of tiles in the BIOME)
project_dir   <- "/home/alber.ipia/Documents/bdc_pantanal"
out_dir <- paste0(project_dir, "/results/", classification_name)
parse_info    <- c("mission", "sp_resolution",
                   "time_resolution", "type",
                   "version", "tile", "date",
                   "end_date", "band")

cube_names <- c("LC8_30_16D_STK-1_041051_2018-01-01_2018-12-31",
                "LC8_30_16D_STK-1_041052_2018-01-01_2018-12-31")

model_file    <- "/home/alber.ipia/Documents/bdc_pantanal/results/first_classification/ml_model.rds"

stopifnot(file.exists(model_file))
stopifnot(dir.exists(project_dir))
stopifnot(dir.exists(out_dir))



#---- Script ----

ml_model <- readRDS(model_file)
my_labels <- ml_model %>%
    environment() %>%
    magrittr::extract2("data") %>%
    dplyr::pull(label) %>%
    unique() %>%
    sort()

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
    cube_date_range <- data_cube %>%
        sits::sits_timeline() %>%
        range()
    prob_file <- "/home/alber.ipia/Documents/bdc_pantanal/results" %>%
        file.path(classification_name) %>%
        list.files(pattern = paste0("^", cube_name, ".+tif$"),
                   full.names = TRUE) %>%
        ensurer::ensure_that(length(.) == 1,
                             err_desc = "Probability file not found!")
    probs_cube <- sits::sits_cube(source = "PROBS",
                                  name = cube_name,
                                  satellite = "LANDSAT-8",
                                  sensor = "OLI",
                                  start_date = cube_date_range[1],
                                  end_date   = cube_date_range[2],
                                  probs_labels = my_labels,
                                  probs_files = prob_file)
    bayesian <- sits::sits_smooth(probs_cube,
                                  type = "bayes",
                                  window_size = 5,
                                  multicores = 10,
                                  memsize = 2,
                                  output_dir = out_dir)
    sits::sits_label_classification(bayesian,
                                    multicores = 10,
                                    memsize = 2,
                                    output_dir = out_dir)
}
