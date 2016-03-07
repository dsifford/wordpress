#!/bin/bash

if [ ! -f /app/wp-config.php ]; then
    /app/init-wp
fi

if [ ! -f /.mysql_db_created ]; then
    /app/init-db
    if [[ ! $(wp core is-installed --allow-root) ]]; then
        wp core install --allow-root \
            --url=localhost:8080 \
            --title="$DB_NAME" \
            --admin_user=root \
            --admin_password="$DB_PASS" \
            --admin_email=admin@"${DB_NAME}".com \
            --skip-email
    fi
fi

[ "$PLUGINS" ] && \
    while IFS=',' read -ra plugin; do
        for i in "${plugin[@]}"; do
            wp plugin is-installed "$i" --allow-root
            if [ $? -eq 0 ]; then
                echo "=> $i is already installed -- SKIPPING..."
            else
                echo "=> Installing plugin: $i"
                wp plugin install "$i" --allow-root
            fi
        done
    done <<< "$PLUGINS"


[ -d /app/wp-content/plugins/akismet ] && \
    wp plugin uninstall akismet hello --deactivate --allow-root

[ -d /app/wp-content/themes/twentyfifteen ] && \
    wp theme delete twentyfifteen twentyfourteen --allow-root

source /etc/apache2/envvars
exec apache2 -D FOREGROUND
