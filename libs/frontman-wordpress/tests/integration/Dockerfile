ARG PHP_VERSION=8.4
FROM docker.io/library/php:${PHP_VERSION}-apache

RUN docker-php-ext-install mysqli \
  && a2enmod rewrite \
  && printf '%s\n' \
    '<Directory /var/www/html/>' \
    '  AllowOverride All' \
    '</Directory>' \
    > /etc/apache2/conf-available/wordpress.conf \
  && a2enconf wordpress

COPY wordpress.tar.gz /tmp/wordpress.tar.gz
RUN tar -xzf /tmp/wordpress.tar.gz --strip-components=1 -C /var/www/html \
  && rm /tmp/wordpress.tar.gz \
  && chown -R www-data:www-data /var/www/html
