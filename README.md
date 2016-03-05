### dsifford/wordpress
> A disposable Docker WordPress environment that just works.

### Requirements
This Dockerfile must be ran in conjunction with a MySQL container, preferably using Docker Compose.

### Environment Variables

##### WordPress Container
- `DB_PASS` (required): Must match `MYSQL_ROOT_PASSWORD`
- `DB_NAME` (optional): Defaults to 'wordpress'
- `PLUGINS` (optional): Comma-separated list of plugins that you depend on.

##### MySQL Container
- `MYSQL_ROOT_PASSWORD` (required): Must match `DB_PASS`

#### Plugin / Theme Development Compose Format
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
            - .:/app/wp-content/plugins/yourplugin # Plugin development
            - .:/app/wp-content/themes/yourtheme   # Theme development
        environment:
            DB_NAME: wordpress
            DB_PASS: root # must match below
            PLUGINS: academic-bloggers-toolkit,co-authors-plus
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
