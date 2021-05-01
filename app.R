
# LIBRERÍAS ---------------------------------------------------------------

library(shiny)
library(tidyverse)
library(lubridate)
library(data.table)
library(leaflet)
library(leaflet.extras)
library(rvest)
library(sf)
library(glue)
library(highcharter)
library(COVID19)

# CONFIGURACIÓN -----------------------------------------------------------

## Configuración de ggplot2

theme_set(theme_minimal() + 
            theme(text = element_text(family = "Trebuchet MS"), 
                  plot.caption = element_text(face = "bold", 
                                              size = 20), 
                  axis.title = element_text(face = "bold"), 
                  plot.title = element_text(face = "bold")))

## Configuración de HighCharts

lang <- getOption("highcharter.lang")
lang$decimalPoint <- "."
lang$months <- c("Enero", "Febrero", "Marzo", "Abril", 
                 "Mayo", "Junio", "Julio", "Agosto", 
                 "Septiembre", "Octubre", "Noviembre", "Diciembre")
lang$shortMonths <- substring(lang$months, 1, 3)
lang$weekdays <- c("Domingo", "Lunes", "Martes", "Miércoles", 
                   "Jueves", "Viernes", "Sábado")

options(highcharter.lang = lang)

# CARGANDO BD -------------------------------------------------------------

dfFallecidos <- fread("https://cloud.minsa.gob.pe/s/Md37cjXmjT9qYSa/download",
                      na.strings = c("", "NULL"), encoding = "UTF-8") %>%
  as_tibble() %>%
  # mutate_if(is.character, ~ str_conv(., "latin1")) %>%
  mutate_if(is.character, str_to_title) %>%
  mutate_at("FECHA_FALLECIMIENTO", ymd)
# mutate_at("FECHA_FALLECIMIENTO", ~as.Date(., tryFormats = "%d%m%Y"))

dfPositivos <- fread("https://cloud.minsa.gob.pe/s/Y8w3wHsEdYQSZRp/download",
                     na.strings = c("", "NULL"), encoding = "UTF-8") %>%
  as_tibble() %>%
  # mutate_if(is.character, ~ str_conv(., "latin1")) %>%
  mutate_if(is.character, str_to_title) %>%
  mutate_at("FECHA_RESULTADO", ymd)

dfVacunados <- fread("https://cloud.minsa.gob.pe/s/ZgXoXqK2KLjRLxD/download", 
                     na.strings = c("", "NULL"), encoding = "UTF-8") %>% 
  as_tibble() %>% 
  mutate_if(is.character, str_to_title) %>% 
  mutate_at(vars(FECHA_VACUNACION), ymd)

dfPeruCovid <- covid19("peru") %>% 
  ungroup() %>% 
  as_tibble() %>% 
  mutate_if(is.numeric, ~replace_na(., 0))

dfCovidNacional <- dfPeruCovid %>% 
  ungroup() %>% 
  filter(confirmed != 0) %>% 
  select(date:icu, -vent) %>% 
  mutate(recovered = case_when(date == "2020-07-27" & recovered == 2727547 ~ 272547, 
                               date == "2020-10-02" & recovered == 690528 ~ 695645, 
                               date == "2021-02-24" & recovered == 0 ~ 1204050, 
                               TRUE ~ recovered)) %>% 
  rename("fecha" = "date",
         "pruebas_acum" = "tests", 
         "confirmados_acum" = "confirmed", 
         "recuperados_acum" = "recovered", 
         "muertes_acum" = "deaths", 
         "hospitalizados_acum" = "hosp", 
         "uci_acum" = "icu") %>% 
  mutate(activos_acum = confirmados_acum - recuperados_acum - muertes_acum, 
         confirmados_nuevos = confirmados_acum - lag(confirmados_acum, default = 0), 
         recuperados_nuevos = recuperados_acum - lag(recuperados_acum, default = 0), 
         muertes_nuevos = muertes_acum - lag(muertes_acum, default = 0), 
         pruebas_nuevos = pruebas_acum - lag(pruebas_acum, default = 0), 
         uci_nuevos = uci_acum - lag(uci_acum, default = 0), 
         hospitalizados_nuevos = hospitalizados_acum - lag(hospitalizados_acum, 
                                                           default = 0), 
         activos_nuevos = activos_acum - lag(activos_acum, default = 0))

while(tail(dfCovidNacional$confirmados_acum, 2)[1] == tail(dfCovidNacional$confirmados_acum, 2)[2] | tail(dfCovidNacional$recuperados_acum, 1) == 0){
  dfCovidNacional <- dfCovidNacional %>% 
    slice(-n())
}

meses <- c("Enero", "Febrero", "Marzo", "Abril", 
           "Mayo", "Junio", "Julio", "Agosto", "Septiembre", 
           "Octubre", "Noviembre", "Diciembre")

dfPeru <- raster::getData(name = "GADM", country = "PER", level = 1)
# dfPeru <- st_read("../DASHBOARDS/data/DEPARTAMENTOS.shp")
# dfPeru <- rename(dfPeru, DEPARTAMENTO = DEPARTAMEN)

if(require("rnaturalearth")){
  library(rnaturalearth)
}else{
  devtools::install_github("ropensci/rnaturalearth")
  library(rnaturalearth)
}

if(require("rnaturalearthhires")){
  library(rnaturalearthhires)
}else{
  devtools::install_github("ropensci/rnaturalearthhires")
  library(rnaturalearthhires)
}

if(require("rgeos")){
  library(rgeos)
}else{
  install.packages("rgeos")
  library(rgeos)
}

dfPeru <- ne_states(country = "peru", returnclass = "sf") %>% 
  mutate_at("name", ~ stringi::stri_trans_general(., "latin-ASCII") %>% 
              str_to_upper()) %>%  
  # filter(name != "LIMA PROVINCE") %>%
  mutate(name = recode(name,
                       "LIMA" = "LIMA METROPOLITANA", 
                       "LIMA PROVINCE" = "LIMA PROVINCIAS")) %>%
  rename("DEPARTAMENTO" = "name")