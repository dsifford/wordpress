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
- `PLUGINS` (optional): Comma-separated list of plugins that you depend on.
- `SEARCH_REPLACE` (optional): Comma-separated string in the form of `current-url`,`replacement-url`.
    - When defined, `current-url` will be replaced with `replacement-url` on build (useful for development environments utilizing a database copied from a live site).
    - **IMPORTANT NOTE:** If you are running Docker on Mac or PC (using Docker Machine), your replacement url MUST be the output of the following command: `echo $(docker-machine ip <your-machine-name>):8080`

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
            - ./data:/data # Required if importing an existing database
            - ./yourplugin:/app/wp-content/plugins/yourplugin # Plugin development
            - ./yourtheme:/app/wp-content/themes/yourtheme   # Theme development
        environment:
            DB_NAME: wordpress
            DB_PASS: root # must match below
            PLUGINS: academic-bloggers-toolkit,co-authors-plus
            SEARCH_REPLACE: yoursite.com,localhost:8080
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
