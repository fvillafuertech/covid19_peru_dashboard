FROM rocker/shiny:4.0.3

RUN apt-get update && apt-get install \
  libcurl4-openssl-dev \
  libv8-dev \
  curl -y \
  libpq-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libxml2-dev \
  make \
  pandoc \
  libicu-dev \
  zlib1g-dev \
  libssl-dev \
  libpng-dev \
  libudunits2-dev \
  libglpk-dev \
  libgmp3-dev
 
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:ubuntugis/ppa
RUN apt-get update
RUN apt-get install -y libgdal-dev
RUN apt-get install -y gdal-bin
RUN apt-get install -y libgeos-dev
RUN apt-get install -y libproj-dev

RUN mkdir -p /var/lib/shiny-server/bookmarks/shiny

# Instalar paquete remotes para controlar las versiones de otros paquetes
RUN R -e 'install.packages("remotes", repos="http://cran.rstudio.com")'

# Descargar e instalar paquetes de R necesarios para el app
RUN R -e 'remotes::install_version(package = "flexdashboard", version = "0.5.2", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "shiny", version = "1.6.0", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "tidyverse", version = "1.3.0", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "lubridate", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "data.table", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "leaflet", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "leaflet.extras", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "rvest", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "sf", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "ggthemes", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "glue", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "highcharter", dependencies = TRUE)'
RUN R -e 'remotes::install_version(package = "COVID19", version = "2.3.2", dependencies = TRUE)'

# Copiar el app a la imagen de shinyapps /srv/shiny-server/
COPY . /srv/shiny-server/
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chown shiny:shiny /srv/shiny-server/

# Configurar permisos en caso de que sea desarrollado desde windows
RUN chmod -R 755 /srv/shiny-server/

EXPOSE 8080
