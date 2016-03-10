FROM tutum/apache-php
MAINTAINER Derek P Sifford <dereksifford@gmail.com>
ENV DEBIAN_FRONTEND noninteractive

# Install mysql-client
RUN apt-get update && apt-get install -y --no-install-recommends \
        mysql-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Install wp-cli & WordPress
WORKDIR /app
RUN curl \
        -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /run.sh https://raw.githubusercontent.com/dsifford/wordpress/master/run.sh \
    && chmod +x /usr/local/bin/wp /run.sh \
    && wp core download --allow-root \
    && chown -R www-data:www-data /app /var/www/html \
    && sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf \
    && a2enmod rewrite

# Run the server
EXPOSE 80 443
CMD ["/run.sh"]
