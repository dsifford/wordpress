FROM ubuntu:trusty
MAINTAINER Derek P Sifford <dereksifford@gmail.com>

ENV TERM xterm

# NGINX
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D43A36E6 \
    && echo "deb http://ppa.launchpad.net/rtcamp/nginx/ubuntu trusty main " >> /etc/apt/sources.list \
    && echo "deb-src http://ppa.launchpad.net/rtcamp/nginx/ubuntu trusty main" >> /etc/apt/sources.list


RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        curl \
        less \
        mariadb-client \
        nginx-custom \
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
RUN mkdir -p var/www/{22222/{cert,htdocs/{db/adminer,fpm/status,php}},wordpress/{conf,htdocs,logs}}
    && curl \
        -o /var/www/22222/htdocs/db/adminer/index.php http://www.adminer.org/latest.php \
        -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /etc/nginx/sites-available/wordpress https://raw.githubusercontent.com/dsifford/wordpress/nginx/config/wordpress.conf \
        -o /etc/nginx/nginx.conf https://raw.githubusercontent.com/dsifford/wordpress/nginx/config/nginx.conf \
        -o /run.sh https://raw.githubusercontent.com/dsifford/wordpress/nginx/run.sh \
    && chmod +x /usr/local/bin/wp /run.sh \
    && sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini \
    && sed -i "s!listen = /var/run/php5-fpm.sock!listen = unix:/tmp/php-cgi.socket!g" /etc/php5/fpm/pool.d/www.conf \
    && ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress \
    # && ln -s /etc/nginx/sites-available/22222 /etc/nginx/sites-enabled/22222 \
    && chown -R www-data:www-data /var/www/ \
    && wp cli update --nightly --yes --allow-root \
    && /usr/sbin/php5enmod mcrypt \
    && service php5-fpm restart


WORKDIR /var/www/wordpress/htdocs
EXPOSE 22 80 443 9000 11371 22222
CMD ["/run.sh"]
