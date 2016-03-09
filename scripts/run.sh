#!/bin/bash

[ "$DB_NAME" ] || DB_NAME='wordpress'
[ "$DB_PASS" ] || DB_PASS='root'

# Pause until MySQL is available for connections
printf "=> Waiting for MySQL to initialize... \n"
while ! mysqladmin ping --host=db --password=$DB_PASS --silent; do
    sleep 1
done

# Configure WordPress
printf "=> Configuring WordPress...\n"
if [ ! -f /app/wp-config.php ]; then
    /app/init-wp
else
    printf "=> wp-config.php exists. SKIPPING...\n\n"
fi

# Install Database
if [ ! "$(wp core is-installed --allow-root >/dev/null 2>&1 && echo $?)" ]; then
    /app/init-db
else
    printf "=> Database '%s' exists. SKIPPING...\n\n" "$DB_NAME"
fi

# Adjust Filesystem Permissions
printf "=> Adjusting Filesystem Permissions... "
groupadd -f docker && usermod -aG docker www-data
find /app -type d -exec chmod 755 {} \;
find /app -type f -exec chmod 644 {} \;
chmod -R 775 /app/wp-content/uploads \
    && chown -R :docker /app/wp-content/uploads
printf "Done!\n\n"

# Install Plugins
[ "$PLUGINS" ] && \
    while IFS=',' read -ra plugin; do
        for i in "${!plugin[@]}"; do
            wp plugin is-installed "${plugin[$i]}" --allow-root
            if [ $? -eq 0 ]; then
                printf "=> ($((i+1))/${#plugin[@]}) Plugin '%s' already installed. SKIPPING...\n" "${plugin[$i]}"
            else
                printf "=> ($((i+1))/${#plugin[@]}) Installing plugin: %s\n" "${plugin[$i]}"
                wp plugin install "${plugin[$i]}" --allow-root
            fi
        done
    done <<< "$PLUGINS"

[ -d /app/wp-content/plugins/akismet ] && \
    wp plugin uninstall akismet hello --deactivate --allow-root

[ -d /app/wp-content/themes/twentyfifteen ] && \
    wp theme delete twentyfifteen twentyfourteen --allow-root

source /etc/apache2/envvars
exec apache2 -D FOREGROUND
