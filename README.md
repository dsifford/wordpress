### dsifford/wordpress
> A disposable Docker WordPress environment that just works, inspired by [visiblevc/wordpress-starter](https://github.com/visiblevc/wordpress-starter).

## Requirements
This Dockerfile must be ran in conjunction with a MySQL container, preferably using Docker Compose.

#### Importing an existing database
If you have an exported `.sql` file from an existing website, drop the file into a folder called `data` and create a volume in the wordpress image at `/data`. The dockerfile will automatically apply your database to the development environment.

## Environment Variables

### WordPress Container
Variable Name | Default Value | Description
-------------|---------------|------------|--------
`DB_PASS`|`null` (**required**)|Password to the linked MySQL (MariaDB) database. Must match `MYSQL_ROOT_PASSWORD`
`DB_NAME`| `wordpress` | Name of the database for your WordPress installation.
`PHP_VERSION` | `5.6` | The version of PHP you wish to use (Only `5.6` and `7.0` are accepted)
`LOCALHOST`| `false` | Set to `true` if this is an installation meant to be run on localhost. (This is what you'd choose for development)
`SITE_NAME`| `wordpress` | Name (including top-level-domain) of your site. <br>**Note:** This is required if `LOCALHOST` is `false`.
`PLUGINS`| `null` | Comma-separated list (or yaml array) of plugins that you depend on.
`THEMES` | `null` | Comma-separated list (or yaml array) of themes that you depend on.
`SEARCH_REPLACE` | `null` | Comma-separated string in the form of `current-url`,`replacement-url`.<br>When defined, `current-url` will be replaced with `replacement-url` on build (useful for development environments utilizing a database copied from a live site).<br>**IMPORTANT NOTE:** If you are running Docker on Mac or PC (using Docker Machine), your replacement url MUST be the output of the following command: `echo $(docker-machine ip <your-machine-name>):8080`
`WP_DEBUG` | `false` | Enables `WP_DEBUG` in `wp-config.php`
`WP_DEBUG_LOG` | `false` | Enables `WP_DEBUG_LOG` in `wp-config.php`
`WP_DEBUG_DISPLAY` | `false` | Enables `WP_DEBUG_DISPLAY` in `wp-config.php`

### MySQL Container
Variable Name | Default Value | Description
-------------|---------------|------------|--------
`MYSQL_ROOT_PASSWORD` | `null` (required) | Must match `DB_PASS`

## Example Plugin / Theme Development Compose Format
```yml
version: '2'
services:
  wordpress:
    image: dsifford/wordpress:nginx
    links:
      - db
    ports:
      - 22222:22222
      - 8080:80
      - 443:443
    volumes:
      - ./data:/data # The directory where your SQL backup is stored (if applicable)
      - ./myplugin:/var/www/yoursite.com/htdocs/wp-content/plugins/myplugin # Plugin volume
      - ./mytheme:/var/www/yoursite.com/htdocs/wp-content/themes/mytheme # Theme volume
    environment:
      # Build
      PHP_VERSION: 5.6
      LOCALHOST: 'false'
      SITE_NAME: yoursite.com

      # Database
      DB_PASS: root # must match below
      DB_NAME: wordpress
      DB_USER: root

      # WordPress
      ADMIN_EMAIL: admin@wordpress.com
      PLUGINS: >-
        academic-bloggers-toolkit,
        co-authors-plus,
        rest-api
      THEMES: twentysixteen
      SEARCH_REPLACE: yoursite.com,localhost:8080
      WP_DEBUG: 'false'
      WP_DEBUG_LOG: 'false'
      WP_DEBUG_DISPLAY: 'true'
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
