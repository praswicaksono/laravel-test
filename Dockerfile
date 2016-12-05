FROM debian:jessie

MAINTAINER SC <shin@alphacode.my>

# Ensure UTF-8
ENV LANGUAGE   en_US.UTF-8

# Run require steps to update to php 7

RUN echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list

RUN gpg --keyserver keys.gnupg.net --recv-key 89DF5277 && gpg -a --export 89DF5277 | apt-key add -

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --force-yes -y \
  software-properties-common \
  wget

RUN wget https://www.dotdeb.org/dotdeb.gpg
RUN apt-key add dotdeb.gpg

# Install packages
RUN apt-get install --force-yes -y \
  software-properties-common \
  nginx \
  curl \
  git-core \
  php7.0 \
  php7.0-fpm \
  php7.0-cli \
  php7.0-mysql \
  php7.0-mcrypt \
  php7.0-redis \
  php7.0-gd \
  php7.0-curl \
  php7.0-memcached \
  php7.0-mbstring \
  php7.0-xml \
  php7.0-zip unzip

# START php7.0-fpm
RUN service php7.0-fpm start

# Configure Supervisor
RUN apt-get install --force-yes -y supervisor
ADD dockerfiles/nginx-supervisor.ini /etc/supervisor.d/nginx-supervisor.ini

# Clean cache
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
           /tmp/* \
           /var/tmp/*

RUN mkdir -p /etc/nginx && \
    mkdir -p /var/run/php-fpm && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /var/www && \
    mkdir -p /root/.ssh

# Configure PHP
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf && \
    echo "clear_env = no" >> /etc/php/7.0/fpm/php-fpm.conf
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.0/fpm/php.ini
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini
RUN sed -i -e "s/;clear_env\s*=\s*no/clear_env = no/g" /etc/php/7.0/fpm/pool.d/www.conf
RUN phpenmod mcrypt

# Configure timezone
#RUN locale-gen ${LANGUAGE}

# Copy source code
RUN rm -rf /var/www/*
ADD . /var/www/

# Install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# Expose volumes
#VOLUME ["/var/www", "/etc/nginx/sites-available", "/etc/nginx/sites-enabled"]

# Setup laravel
WORKDIR /var/www

# Configure nginx
RUN rm /etc/nginx/nginx.conf
ADD dockerfiles/nginx.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/sites-available/default
ADD dockerfiles/admin.conf /etc/nginx/sites-available/default
ADD dockerfiles/nginx_env.conf /etc/nginx/main.d/env.conf

# COPY config.json /root/.composer/config.json

RUN composer install --no-dev --no-interaction --prefer-dist
RUN chown -R www-data:www-data /var/www/ && \
    chown -R www-data:www-data /var/www/storage

# Comment out line below if you copy .env file locally
# RUN chown www-data /var/www/.env

# PORTS
EXPOSE 80 443

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.d/nginx-supervisor.ini"]
