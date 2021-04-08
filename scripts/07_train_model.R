library(dplyr)
library(ensurer)
library(lubridate)
library(purrr)
library(sits)



#--- Configuration ----

samples_file <- "/home/alber.ipia/Documents/bdc_pantanal/data/samples/som/samples_pantanal_som.rds"
model_file  <- "/home/alber.ipia/Documents/bdc_pantanal/results/third_classification/ml_model.rds"
stopifnot(file.exists(samples_file))
stopifnot(dir.exists(dirname(model_file)))

ml_method <- sits::sits_rfor(trees = 2000)

source("./scripts/00_util.R")



#---- Script ----

samples_tb <- samples_file %>%
    readRDS() %>%
    #dplyr::filter(eval == "clean") %>%
    dplyr::select(-id, -old_label, -id_sample, -id_neuron, -eval, -post_prob) %>%
    dplyr::mutate(label = dplyr::recode(label,
                                             "FORMAÇÃO SAVÃNICA"  = "F. CAMPESTRE SAVÃNICA",
                                             "FORMAÇÃO CAMPESTRE" = "F. CAMPESTRE SAVÃNICA")) %>%
    is_sits_valid()
samples_tb %>%
    dplyr::count(label)
# NEW
# label                              n
# 1 AGRICULTURA                      695
# 2 CAMPO ALAGADO E ÁREA PANTANOSA   209
# 3 F. CAMPESTRE SAVÃNICA           1181
# 4 FORMAÇÃO FLORESTAL              1586
# 5 PASTAGEM                        2930
#
# ORIGINAL
# label                              n
# 1 AGRICULTURA                      695
# 2 CAMPO ALAGADO E ÁREA PANTANOSA   209
# 3 FORMAÇÃO CAMPESTRE               538
# 4 FORMAÇÃO FLORESTAL              1586
# 5 FORMAÇÃO SAVÃNICA                643
# 6 PASTAGEM                        2930

ml_model <- sits::sits_train(samples_tb,
                             ml_method = ml_method)

saveRDS(object = ml_model,
        file = model_file)
