### dsifford/wordpress
> A disposable Docker WordPress environment that just works.

### Requirements
This Dockerfile must be ran in conjunction with a MySQL container, preferably using Docker Compose.

#### Plugin Development Compose Format
```yml
version: '2'
services:
    wordpress:
        image: dsifford/wordpress
        links:
            - db
        ports:
            - 8080:80
            - 443:443
        volumes:
            - .:/app/wp-content/plugins/yourplugin
        environment:
            DB_NAME: wordpress
            DB_PASS: root # must match below
    db: # Must be named 'db'
        image: mysql:5.7
        ports:
            - 3306:3306
        volumes_from:
            - data
        environment:
            MYSQL_ROOT_PASSWORD: root
    data:
        image: busybox
        volumes:
            - /var/lib/mysql
```

#### Theme Development Compose Format
```yml
version: '2'
services:
    wordpress:
        image: dsifford/wordpress
        links:
            - db
        ports:
            - 8080:80
            - 443:443
        volumes:
            - .:/app/wp-content/themes/yourtheme
        environment:
            DB_NAME: wordpress
            DB_PASS: root # must match below
    db: # Must be named 'db'
        image: mysql:5.7
        ports:
            - 3306:3306
        volumes_from:
            - data
        environment:
            MYSQL_ROOT_PASSWORD: root
    data:
        image: busybox
        volumes:
            - /var/lib/mysql
```
