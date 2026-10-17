FROM php:8.5-apache

# Set IANSEO_VERSION as a build argument and environment variable
ARG IANSEO_VERSION
ENV IANSEO_VERSION=$IANSEO_VERSION
# ---------------------------------------------------------------

# Install dependencies and clean up apt cache to reduce image size
RUN apt-get update && apt-get install -y \
    # Basic tools
    unzip \
    curl \
    jq \
    dos2unix \
    # client MySQL for command line
    default-mysql-client \
    # lib php
    libicu-dev \
    libmagickwand-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libxml2-dev \
    libzip-dev \
    libonig-dev \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
# ------------------------------------------------------------------

# Install extensions PHP (intl, gd, mysqli, pdo_mysql, zip, gettext)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    intl \
    gd \
    mysqli \
    pdo_mysql \
    zip \
    gettext
# ------------------------------------------------------------------

# Install Imagick (PECL)
RUN pecl install imagick \
    && docker-php-ext-enable imagick
# ----------------------

# Drop in an assortment of configuration information and the ianseo files
COPY web/ianseo.conf /etc/apache2/conf-available/
COPY web/php.ini /usr/local/etc/php/
COPY web/phpinfo.php /tmp
# -----------------------------------------------------------------------

    
COPY web/web_prep.sh /usr/local/bin/web_prep.sh
RUN dos2unix /usr/local/bin/web_prep.sh && chmod +x /usr/local/bin/web_prep.sh
RUN chmod +x /usr/local/bin/web_prep.sh

ENTRYPOINT ["/usr/local/bin/web_prep.sh"]