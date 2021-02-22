FROM php:7.3-fpm
MAINTAINER Ihor Furseyev <i.furseyev@atwix.com>

# Pre-repository setup: Add support for HTTPS repositories
RUN apt-get update -q; \
    apt-get install -qy apt-transport-https

# Instal gnupg
RUN apt-get install -qy gnupg

# Repository: Yarn package manager
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
COPY ./config/etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.list

# Repository: Node.js
RUN curl -sS https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
COPY ./config/etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.list

# Repository: ElasticSearch
RUN curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
COPY ./config/etc/apt/sources.list.d/elastic-7.x.list /etc/apt/sources.list.d/elastic-7.x.list

# Upgrade/install packages
RUN mkdir -p /usr/share/man/man1
RUN apt-get update -q; \
    apt-get upgrade -qy; \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy \
      bash supervisor \
      build-essential \
      curl htop git vim wget \
      nginx-extras mariadb-client redis-tools \
      nullmailer mailutils \
      nodejs yarn \
      ruby ruby-dev rake \
      libxml2-utils \
      libcurl4-openssl-dev \
      libfreetype6-dev \
      libicu-dev \
      libjpeg62-turbo-dev \
      libmcrypt-dev \
      libpng-dev \
      libxml2-dev libxslt1-dev \
      zlib1g-dev \
      libzip-dev \
      procps \g
      default-jdk default-jre \
      elasticsearch=7.10.2

RUN docker-php-ext-install -j$(nproc) bcmath intl opcache pdo_mysql soap xsl zip iconv sockets
RUN pecl install mcrypt-1.0.3
RUN docker-php-ext-enable mcrypt
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd
RUN pecl install xdebug-2.9.2
RUN apt-get clean -qy; \
    rm -f /etc/nginx/sites-enabled/default; \
    ln -sf /dev/stdout /var/log/nginx/access.log; \
    ln -sf /dev/stderr /var/log/nginx/error.log; \
    rm -rf /var/lib/apt; \
    rm -rf /usr/src/php

# Install extra helper stuff
COPY src/wait-for-port /usr/local/bin/wait-for-port
RUN curl -sL https://getcomposer.org/download/1.10.10/composer.phar -o /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer
RUN curl -sL https://files.magerun.net/n98-magerun2-2.1.2.phar -o /usr/local/bin/n98-magerun2
RUN chmod +x /usr/local/bin/n98-magerun2

# Install config files and tester site
COPY ./config/nginx /etc/nginx
COPY ./config/php /usr/local/etc/php
COPY ./config/php-fpm /usr/local/etc/php-fpm.d
COPY ./config/supervisor/conf.d /etc/supervisor/conf.d
COPY ./tester /usr/share/nginx/tester

# nullmailer
RUN rm -f /var/spool/nullmailer/trigger; \
    mkfifo /var/spool/nullmailer/trigger; \
    chown mail:root /var/spool/nullmailer/trigger; \
    chmod 0622 /var/spool/nullmailer/trigger

# Set working directory
RUN chown -R www-data:www-data /var/www
WORKDIR /var/www

# Default command
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

# Expose ports
EXPOSE 80
