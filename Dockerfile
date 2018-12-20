FROM php:7.1-fpm-alpine
MAINTAINER Rakshit Menpara <rakshit@improwised.com>

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV composer_hash 93b54496392c062774670ac18b134c3b3a95e5a5e5c8f1a9f115f203b75bf9a129d5daa8ba6a13e2cc8a1da0806388a8
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

################## INSTALLATION STARTS ##################

RUN set -ex \
  && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS curl-dev cyrus-sasl-dev gmp-dev icu-dev imagemagick-dev \
    libgsasl-dev libmcrypt-dev libmemcached-dev libtool libxml2-dev \
    mariadb-dev sqlite-dev  zlib-dev \

  # Install production dependencies
  && apk add --no-cache --virtual .run-deps \
    bash curl g++ gcc git gmp imagemagick libc-dev libpng-dev make mysql-client \
    nodejs nodejs-npm openssh-client mariadb-client sudo rsync ca-certificates \
    dialog libjpeg supervisor vim wget nginx libmemcached-libs zlib \


  # Install PECL and PEAR extensions
  && pecl install \
    apcu-5.1.16 \
    memcached-3.0.4 \
    redis-4.2.0 \

  # Install and enable php extensions
  && docker-php-ext-enable \
    apcu memcached redis \
  && docker-php-ext-install \
    bcmath ctype curl dom exif fileinfo gd gmp iconv intl json \
    mbstring mcrypt mysqli opcache pcntl pdo pdo_mysql \
    pdo_sqlite phar posix session simplexml soap sockets tidy \
    tokenizer xml xmlwriter zip \

  # Create directories
  && mkdir -p /etc/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /etc/nginx/sites-available \
    && mkdir -p /etc/nginx/sites-enabled \
    && mkdir -p /var/log/supervisor \
    && rm -Rf /var/www/* \
    && rm -Rf /etc/nginx/nginx.conf \
  # Composer
  && php7 -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php7 -r "if (hash_file('SHA384', 'composer-setup.php') === '${composer_hash}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php7 composer-setup.php --install-dir=/usr/bin --filename=composer \
    && php7 -r "unlink('composer-setup.php');" \
  # Cleanup
  && apk del -f .build-deps

##################  INSTALLATION ENDS  ##################

##################  CONFIGURATION STARTS  ##################

ADD rootfs /

RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf && \
    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
    chown -R nginx:nginx /var/www && \
    mkdir -p /var/www/storage/logs/ && \
    touch /var/www/storage/logs/laravel.log /var/log/nginx/error.log /var/log/php7/error.log

##################  CONFIGURATION ENDS  ##################

EXPOSE 443 80

WORKDIR /var/www

ENTRYPOINT ["dockerize", \
    "-template", "/etc/php7/php.ini:/etc/php7/php.ini", \
    "-template", "/etc/php7/php-fpm.conf:/etc/php7/php-fpm.conf", \
    "-template", "/etc/php7/php-fpm.d:/etc/php7/php-fpm.d", \
    "-stdout", "/var/www/storage/logs/laravel.log", \
    "-stdout", "/var/log/nginx/error.log", \
    "-stdout", "/var/log/php7/error.log", \
    "-poll"]

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
