# Download images from the Brazil Data Cubes website.

library(dplyr)
library(readr)
library(sits)
library(tidyr)



#---- Setup ----

source("~/Documents/bdc_access_key.R")
access_key <- Sys.getenv("BDC_ACCESS_KEY")
stopifnot(access_key != "")


cube_list_dir <- "/home/alber.ipia/Documents/bdc_pantanal/data/cube/image_list"
out_dir       <- "/home/alber.ipia/Documents/bdc_pantanal/data/cube"
stopifnot(dir.exists(cube_list_dir))
stopifnot(dir.exists(out_dir))



#---- Util ----

# Read and format the file URL in a text file.
read_cube_list <- function(cube_file, out_dir){
    cube_tb <-  cube_file %>%
        readr::read_delim(delim = " ",
                          col_names = FALSE,
                          col_types = "c") %>%
        magrittr::set_names("url_token") %>%
        tibble::as_tibble() %>%
        # NOTE: Remove tokens from URL
        dplyr::mutate(img_url = dplyr::if_else(stringr::str_detect(url_token,
                                                                   pattern = "\\?"),
                                               stringr::str_extract(url_token, ".+?(?=\\?)"),
                                               url_token)) %>%
        dplyr::mutate(img_name = img_url %>%
                          basename(),
                      file_name = img_name %>%
                          tools::file_path_sans_ext()) %>%
        tidyr::separate(file_name, sep = "_",
                        into = c("mission", "sp_resolution", "time_resolution",
                                 "type", "version", "tile", "start_date",
                                 "end_date", "band")) %>%
        dplyr::filter(band %in% c("band1", "band11", "band12", "band2", "band3",
                                  "band4", "band5", "band6", "band7", "band8",
                                  "band8a", "EVI", "Fmask4", "NDVI")) %>%
        dplyr::mutate(url = stringr::str_c(img_url,
                                           "?access_token=",
                                           access_key)) %>%
        return()
}



#---- Script ----

# Table of files with list of cubes for downloading.
file_tb <- cube_list_dir %>%
    list.files(pattern = ".txt$",
               full.names = TRUE) %>%
    tibble::as_tibble() %>%
    dplyr::rename(file_path = value) %>%
    dplyr::mutate(file_name = file_path %>%
                      tools::file_path_sans_ext() %>%
                      basename()) %>%
    tidyr::separate(col = file_name,
                    into = c("mission", "sp_res", "tm_res", "cube_type", "tile",
                             "first_start_date", "last_start_date"),
                    sep = "_") %>%
    dplyr::mutate(tile_out_dir = file.path(out_dir, tile))


# Read the files in the list of cubes.
cube_tb <- file_tb %>%
    dplyr::select(file_path, tile_out_dir) %>%
    dplyr::mutate(file_name = file_path %>%
                      tools::file_path_sans_ext() %>%
                      basename(),
                  cube_list = purrr::map2(file_path, tile_out_dir,
                                          read_cube_list)) %>%
    tidyr::unnest(cube_list) %>%
    dplyr::mutate(destfile = file.path(out_dir, file_name, img_name)) %>%
    dplyr::select(url, destfile)

# Create directories for the cubes.
dir_vec <- cube_tb %>%
    dplyr::mutate(dir_name = dirname(destfile)) %>%
    dplyr::pull(dir_name) %>%
    unique()
for (my_dir in dir_vec) {
    if (!dir.exists(my_dir))
        dir.create(my_dir)
}

# Download files.
image_tb <- cube_tb %>%
    dplyr::mutate(downloaded = purrr::map2_int(url, destfile,  function(url, destfile) {
        if (file.exists(destfile))
            return(0)

        download.file(url = url,
                      destfile = destfile,
                      method = "auto",
                      quiet = TRUE)
    }))

cube_tb <- cube_tb %>%
    dplyr::mutate(file_exists = file.exists(destfile)) %>%
    ensurer::ensure_that(all(.$file_exists),
                         err_desc = "Some files weren't downloaded!")
