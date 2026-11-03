ARG PHP_VERSION=8.4
FROM docker.io/library/php:${PHP_VERSION}-apache

RUN if grep -q '^VERSION_CODENAME=bullseye$' /etc/os-release; then \
      sed -i 's|deb.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list; \
    fi \
  && apt-get update && apt-get install -y --no-install-recommends libpng-dev \
  && rm -rf /var/lib/apt/lists/* \
  && docker-php-ext-install mysqli gd \
  && a2enmod rewrite ssl \
  && printf '%s\n' \
    '<Directory /var/www/html/>' \
    '  AllowOverride All' \
    '</Directory>' \
    > /etc/apache2/conf-available/wordpress.conf \
  && a2enconf wordpress \
  && printf '%s\n' '<VirtualHost *:443>' \
    'DocumentRoot /var/www/html' 'SSLEngine on' \
    'SSLCertificateFile /tmp/frontman-test.crt' 'SSLCertificateKeyFile /tmp/frontman-test.key' \
    '</VirtualHost>' > /etc/apache2/conf-available/frontman-test-ssl.conf \
  && a2enconf frontman-test-ssl

COPY frontman-test.key frontman-test.crt /tmp/
COPY wordpress.tar.gz /tmp/wordpress.tar.gz
RUN tar -xzf /tmp/wordpress.tar.gz --strip-components=1 -C /var/www/html \
  && rm /tmp/wordpress.tar.gz \
  && chown -R www-data:www-data /var/www/html
