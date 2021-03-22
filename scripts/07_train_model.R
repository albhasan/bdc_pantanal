library(dplyr)
library(ensurer)
library(lubridate)
library(purrr)
library(sits)


#--- Configuration ----

samples_dir <- "/home/alber.ipia/Documents/bdc_pantanal/data/samples"
model_file  <- "/home/alber.ipia/Documents/bdc_pantanal/results/first_classification/ml_model.rds"
stopifnot(dir.exists(samples_dir))
stopifnot(dir.exists(dirname(model_file)))

ml_method <- sits::sits_rfor(trees = 2000)

source("./scripts/00_util.R")



#---- Script ----

samples_tb <- samples_dir %>%
    list.files(pattern = "*.rds",
               full.names = TRUE,
               recursive = TRUE) %>%
    tibble::as_tibble() %>%
    dplyr::rename(file_path = value) %>%
    dplyr::mutate(file_name = file_path %>%
                      tools::file_path_sans_ext() %>%
                      basename()) %>%
    tidyr::separate(file_name,
                    into = c("source", "tile", "start_date", "end_date",
                             "batch" ),
                    sep = "_") %>%
    dplyr::mutate(start_date = lubridate::as_date(start_date),
                  end_date   = lubridate::as_date(end_date)) %>%
    dplyr::filter(start_date >= lubridate::as_date("2018-01-01"),
                  end_date   <= lubridate::as_date("2018-12-31")) %>%
    ensurer::ensure_that(nrow(.) > 0,
                         err_desc = "No sample files were foound!") %>%
    dplyr::mutate(data = purrr::map(file_path, readRDS)) %>%
    dplyr::pull(data) %>%
    dplyr::bind_rows() %>%
    is_sits_valid()

samples_tb %>%
    dplyr::count(label)
# label                              n
# * <chr>                          <int>
# 1 AFLORAMENTO ROCHOSO                1
# 2 CAMPO ALAGADO E ÁREA PANTANOSA   213
# 3 CANA                               1
# 4 FLORESTA PLANTADA                  8
# 5 FORMAÇÃO CAMPESTRE               335
# 6 FORMAÇÃO FLORESTAL               365
# 7 FORMAÇÃO SAVÃNICA                221
# 8 INFRAESTRUTURA URBANA              5
# 9 LAVOURA PERENE                     2
# 10 LAVOURA TEMPORÁRIA                56
# 11 OUTRA ÁREA NÃO VEGETADA            5
# 12 PASTAGEM                         489
# 13 RIO, LAGO E OCEANO                33

ml_model <- sits::sits_train(samples_tb,
                             ml_method = ml_method)

saveRDS(object = ml_model,
        file = model_file)
