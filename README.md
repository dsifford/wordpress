### dsifford/wordpress
> A disposable Docker WordPress environment that just works, inspired by [visiblevc/wordpress-starter](https://github.com/visiblevc/wordpress-starter).

### Requirements
This Dockerfile must be ran in conjunction with a MySQL container, preferably using Docker Compose.

**Importing an existing database**
- If you have an exported `.sql` file from an existing website, drop the file into a folder called `data` and create a volume in the wordpress image at `/data`. The dockerfile will automatically apply your database to the development environment.

### Environment Variables

##### WordPress Container
- `DB_PASS` (required): Must match `MYSQL_ROOT_PASSWORD`
- `DB_NAME` (optional): Defaults to 'wordpress'
- `PLUGINS` (optional): Comma-separated list or yaml array of plugins that you depend on.
- `SITE_NAME` (optional): The name (and top-level-domain) of your site. Defaults to wordpress.
- `LOCALHOST` (optional): Boolean - Is this a development site needing to run locally?
- `SEARCH_REPLACE` (optional): Comma-separated string in the form of `current-url`,`replacement-url`.
    - When defined, `current-url` will be replaced with `replacement-url` on build (useful for development environments utilizing a database copied from a live site).
    - **IMPORTANT NOTE:** If you are running Docker on Mac or PC (using Docker Machine), your replacement url MUST be the output of the following command: `echo $(docker-machine ip <your-machine-name>):8080`
- `WP_DEBUG` (optional): `boolean` enables `WP_DEBUG`.
- `WP_DEBUG_LOG` (optional): `boolean` enables `WP_DEBUG_LOG`.
- `WP_DEBUG_DISPLAY` (optional): `boolean` enables `WP_DEBUG_DISPLAY`.

##### MySQL Container
- `MYSQL_ROOT_PASSWORD` (required): Must match `DB_PASS`

#### Plugin / Theme Development Compose Format
```yml
version: '2'
services:
  wordpress:
    image: dsifford/wordpress:nginx
    links:
      - db
    ports:
      - 8080:80
      - 443:443
    volumes:
      - ./plugin:/app/wp-content/plugins/myplugin
      - ./theme:/app/wp-content/themes/mytheme
    environment:
      DB_PASS: root # must match below
      DB_NAME: wordpress
      SITE_NAME: yoursite.com
      LOCALHOST: 'true'
      PLUGINS: >-
        academic-bloggers-toolkit,
        co-authors-plus,
        rest-api
      SEARCH_REPLACE: yoursite.com,localhost:8080
      WP_DEBUG: 'true'
      WP_DEBUG_LOG: 'true'
      WP_DEBUG_DISPLAY: 'false'
  db: # Must be named 'db'
    image: mariadb:10
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
