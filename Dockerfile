FROM php:7.1-fpm-alpine
MAINTAINER Rakshit Menpara <rakshit@improwised.com>

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_VERSION 1.8.0
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
    mariadb-dev sqlite-dev tidyhtml-dev zlib-dev \

  # Install production dependencies
  && apk add --no-cache --virtual .run-deps \
    bash curl g++ gcc git gmp imagemagick libc-dev libpng-dev make mysql-client \
    nodejs nodejs-npm openssh-client mariadb-client sudo rsync ca-certificates \
    dialog libjpeg supervisor vim wget nginx libmemcached-libs tidyhtml-libs zlib \
    memcached \

  # Install PECL and PEAR extensions
  && pecl install \
    apcu-5.1.16 \
    memcached-3.0.4 \
    redis-4.2.0 \

  # Install and enable php extensions
  && docker-php-ext-enable \
    apcu memcached redis \
  && docker-php-ext-install \
    bcmath exif gd gmp intl mcrypt mysqli opcache pcntl pdo_mysql soap sockets \
    tidy zip \

  # Create directories
  && mkdir -p /etc/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /etc/nginx/sites-available \
    && mkdir -p /etc/nginx/sites-enabled \
    && mkdir -p /var/log/supervisor \
    && rm -Rf /var/www/* \
    && rm -Rf /etc/nginx/nginx.conf \
  # Composer
  && curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/b107d959a5924af895807021fcef4ffec5a76aa9/web/installer \
    && php -r " \
      \$signature = '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061'; \
      \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
      if (!hash_equals(\$signature, \$hash)) { \
          unlink('/tmp/installer.php'); \
          echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
          exit(1); \
      }" \
    && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
    && composer --ansi --version --no-interaction \
    && rm -rf /tmp/* /tmp/.htaccess \
  # Cleanup
  && apk del -f .build-deps

##################  INSTALLATION ENDS  ##################

##################  CONFIGURATION STARTS  ##################

ADD rootfs /

RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf && \
    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
    chown -R nginx:nginx /var/www && \
    mkdir -p /var/www/storage/logs/ /var/log/nginx/ /var/log/php7/ && \
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
