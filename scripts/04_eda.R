library(dplyr)
library(ggplot2)
library(purrr)
library(stringr)
library(tidyr)

samples_tb <- paste0("./data/samples/2018") %>%
    list.files(pattern = "*.rds",
               full.names = TRUE) %>%
    tibble::enframe() %>%
    dplyr::rename(file_path = value) %>%
    dplyr::mutate(rds = purrr::map(file_path, readRDS)) %>%
    dplyr::select(rds) %>%
    tidyr::unnest(rds) %>%
    mutate(cube = "pantanal") %>%
    tidyr::unnest(time_series) %>%
    dplyr::select(-longitude, -latitude, -cube,
                  Label = label) %>%
    dplyr::select(order(colnames(.))) %>%
    dplyr::select(Label, start_date, end_date, Index, everything())

my_date <- samples_tb %>%
    dplyr::select(start_date, end_date) %>%
    unlist() %>%
    lubridate::as_date() %>%
    range() %>%
    paste(collapse = "_")



#---- Plot samples' time series ----

f_plot <- function(x){
    x %>%
        ggplot2::ggplot() +
        ggplot2::geom_boxplot(ggplot2::aes(x = Index,
                                           y = Value,
                                           group = interaction(Index, Band)),
                              outlier.size = 0.5) +
        ggplot2::geom_smooth(ggplot2::aes(x = Index,
                                          y = Value,
                                          group =  Band,
                                          color = Label)) +
        ggplot2::theme(axis.text.x = element_text(angle = 90),
                       strip.text.y = element_blank()) +
        ggplot2::facet_grid(rows = vars(Label),
                            cols = vars(Band)) %>%
        return()
}


plot_tb <- samples_tb %>%
    tidyr::pivot_longer(cols = !tidyselect::all_of(c("start_date",
                                                     "end_date",
                                                     "Label", "Index")),
                        names_to = "Band",
                        values_to = "Value")

plot_tb %>%
    dplyr::filter(Band %in% c("B1", "B2", "B3", "B4")) %>%
    f_plot() +
    ggplot2::ggtitle("L8 samples - Flat bands") +
    ggplot2::ggsave(filename = paste0("./data/samples/plot_samples_bands_flat_",
                                      my_date, ".png"),
                    width = 297,
                    height = 420,
                    units = "mm")

plot_tb %>%
    dplyr::filter(Band %in% c("B5", "B6", "B7")) %>%
    f_plot() +
    ggplot2::ggtitle("L8 samples - Bands") +
    ggplot2::ggsave(filename = paste0("./data/samples/plot_samples_bands_",
                                      my_date, ".png"),
                    width = 297,
                    height = 420,
                    units = "mm")

plot_tb %>%
    dplyr::filter(Band %in% c("EVI", "NDVI")) %>%
    f_plot() +
    ggplot2::ggtitle("L8 samples - Vegetation Indexes") +
    ggplot2::ggsave(filename = paste0("./data/samples/plot_samples_indices_",
                                      my_date, ".png"),
                    width = 297,
                    height = 420,
                    units = "mm")



#---- PCA ----

# Return the standard deviation explained by each principal component.
pca_sd <- function(x){
    x %>%
        prcomp(center = TRUE, scale = TRUE) %>%
        magrittr::extract2("sdev") %>%
        magrittr::set_names(stringr::str_c("PC",
                                           str_pad(1:length(.), pad = "0",
                                                   width = 2))) %>%
        dplyr::bind_rows() %>%
        return()
}

plot_pca <- samples_tb %>%
    dplyr::select(-start_date, -end_date, -Index) %>%
    dplyr::group_by(Label) %>%
    tidyr::nest() %>%
    dplyr::ungroup() %>%
    dplyr::mutate(data_bands = purrr::map(data, dplyr::select, B1:B7),
                  data_indices = purrr::map(data, dplyr::select, EVI:NDVI)) %>%
    dplyr::mutate(pca_bands = purrr::map(data_bands, pca_sd),
                  pca_indices = purrr::map(data_indices, pca_sd))

plot_pca %>%
    tidyr::unnest(pca_bands) %>%
    dplyr::select(-data, -data_bands, -data_indices, -pca_indices) %>%
    tidyr::pivot_longer(cols = tidyselect::starts_with("PC"),
                        names_to = "PC", values_to = "SD") %>%
    dplyr::group_by(Label) %>%
    dplyr::mutate(cum_SD = cumsum(SD),
                  total = sum(SD),
                  cum_norm_SD = cum_SD/total) %>%
    dplyr::select(-total) %>%
    dplyr::ungroup() %>%
    ggplot2::ggplot() +
    ggplot2::geom_step(ggplot2::aes(x = PC, y = cum_norm_SD,
                                    group = Label, color = Label)) +
    ggplot2::geom_hline(yintercept = 0.95, linetype = "dashed") +
    ggplot2::ggtitle("PCA using bands") +
    ggplot2::ylab("Explained SD") +
    ggplot2::ylim(0, 1) +
    ggplot2::ggsave(filename = paste0("./data/samples/plot_samples_pca_bands_",
                                      my_date, ".png"))

plot_pca %>%
    tidyr::unnest(pca_indices) %>%
    dplyr::select(-data, -data_bands, -data_indices, -pca_bands) %>%
    tidyr::pivot_longer(cols = tidyselect::starts_with("PC"),
                        names_to = "PC", values_to = "SD") %>%
    dplyr::group_by(Label) %>%
    dplyr::mutate(cum_SD = cumsum(SD),
                  total = sum(SD),
                  cum_norm_SD = cum_SD/total) %>%
    dplyr::select(-total) %>%
    dplyr::ungroup() %>%
    ggplot2::ggplot() +
    ggplot2::geom_step(ggplot2::aes(x = PC, y = cum_norm_SD,
                                    group = Label, color = Label)) +
    ggplot2::geom_hline(yintercept = 0.95, linetype = "dashed") +
    ggplot2::ggtitle("PCA using indices") +
    ggplot2::ylab("Explained SD") +
    ggplot2::ylim(0, 1) +
    ggplot2::ggsave(filename = paste0("./data/samples/plot_samples_pca_indices_",
                                      my_date, ".png"))
