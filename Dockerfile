FROM ubuntu:trusty
MAINTAINER Derek P Sifford <dereksifford@gmail.com>

ENV TERM xterm

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        build-essential \
        git \
        mariadb-client \
        python3-setuptools \
        python3-dev \
        python3-apt \
        rsync \
        unzip \
        vim

RUN git config --global user.name "root" \
    && git config --global user.email root@localhost.com \
    && curl \
        -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /ee https://raw.githubusercontent.com/EasyEngine/easyengine/master/install \
        -o /run.sh https://raw.githubusercontent.com/dsifford/wordpress/nginx/run.sh \
    && chmod +x /ee /run.sh /usr/local/bin/wp \
    && bash ee \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 22 80 443 9000 11371 22222
CMD ["/run.sh"]
