FROM ubuntu:trusty
MAINTAINER Derek P Sifford <dereksifford@gmail.com>

ENV TERM xterm

# NGINX
RUN apt-key adv --fetch-keys http://nginx.org/keys/nginx_signing.key \
    && echo "deb http://nginx.org/packages/ubuntu/ trusty nginx" >> /etc/apt/sources.list \
    && echo "deb-src http://nginx.org/packages/ubuntu/ trusty nginx" >> /etc/apt/sources.list


RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        curl \
        less \
        mariadb-client \
        nginx \
        php-apc \
        php-pear \
        php5-curl \
        php5-fpm \
        php5-gd \
        php5-mcrypt \
        php5-mysql \
        unzip \
        vim \
    && rm -rf /var/lib/apt/lists/*


# Adminer, WP-CLI, and config files
RUN mkdir -p \
        /usr/share/nginx/adminer \
        /usr/share/nginx/wordpress \
    && curl \
        -o /usr/share/nginx/adminer/index.php http://www.adminer.org/latest.php \
        -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /etc/nginx/conf.d/wordpress.conf https://raw.githubusercontent.com/dsifford/wordpress/nginx/config/wordpress.conf \
        -o /etc/nginx/nginx.conf https://raw.githubusercontent.com/dsifford/wordpress/nginx/config/nginx.conf \
        -o /run.sh https://raw.githubusercontent.com/dsifford/wordpress/nginx/run.sh \
    && chmod +x /usr/local/bin/wp /run.sh \
    && sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini \
    && ln -s /usr/share/nginx/wordpress/ /app \
    && chown -R www-data:www-data /usr/share/nginx/ \
    && wp cli update --nightly --yes --allow-root \
    && /usr/sbin/php5enmod mcrypt \
    && service php5-fpm restart \
    && service nginx start


WORKDIR /app
EXPOSE 80 443
CMD ["/run.sh"]
