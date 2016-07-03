FROM ubuntu:trusty
MAINTAINER Derek P Sifford <dereksifford@gmail.com>

ENV TERM xterm

RUN printf "%s\n%s\n" \
        "deb http://ppa.launchpad.net/saiarcot895/myppa/ubuntu trusty main" \
        "deb-src http://ppa.launchpad.net/saiarcot895/myppa/ubuntu trusty main" \
        >> /etc/apt/sources.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DC058F40

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-fast \
        curl \
        build-essential \
        git \
        mariadb-client \
        python3-setuptools \
        python3-dev \
        python3-apt \
        unzip \
        vim \
    && mv /usr/bin/apt-get /usr/bin/old-apt-get \
    && ln -s /usr/sbin/apt-fast /usr/bin/apt-get \
    && sed -i "s/_APTMGR=apt-get/_APTMGR=old-apt-get/" /etc/apt-fast.conf

RUN git config --global user.name "root" \
    && git config --global user.email root@localhost.com \
    && curl \
        -o /ee https://raw.githubusercontent.com/EasyEngine/easyengine/master/install \
        -o /run.sh https://raw.githubusercontent.com/dsifford/wordpress/nginx/run.sh \
    && chmod +x /ee /run.sh \
    && bash ee \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 22 80 443 9000 11371 22222
CMD ["/run.sh"]
