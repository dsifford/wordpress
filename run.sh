#!/bin/bash

[ "$DB_NAME" ] || DB_NAME='wordpress'
[ "$DB_PASS" ] || DB_PASS='root'
[ "$SEARCH_REPLACE" ] || SEARCH_REPLACE=false

# Configure wp-cli
if [ ! -f /app/wp-cli.yml ]; then
	cat > /app/wp-cli.yml <<-EOF
	quiet: true
	apache_modules:
	  - mod_rewrite

	core config:
	  dbuser: root
	  dbpass: $DB_PASS
	  dbname: $DB_NAME
	  dbhost: db:3306

	core install:
	  url: $([ "$AFTER_URL" ] && echo "$AFTER_URL" || echo localhost:8080)
	  title: $DB_NAME
	  admin_user: root
	  admin_password: $DB_PASS
	  admin_email: admin@${DB_NAME}.com
	  skip-email: true
	EOF
fi

# Pause until MySQL is available for connections
printf "=> Waiting for MySQL to initialize... \n"
while ! mysqladmin ping --host=db --password=$DB_PASS --silent; do
    sleep 1
done

# Configure WordPress
printf "=> Configuring WordPress...\n"
if [ ! -f /app/wp-config.php ]; then

	# wp.config.php
	printf "=> Generating wp.config.php file... "
	sudo -u www-data wp core config
	printf "Done!\n"

else
    printf "=> wp-config.php exists. SKIPPING...\n"
fi

# Install Database
if [ ! "$(wp core is-installed --allow-root >/dev/null 2>&1 && echo $?)" ]; then

	printf "=> Creating database '%s'... " "$DB_NAME"
	sudo -u www-data wp db create
	printf "Done!\n"

	# If an SQL file exists in /data => load it
	if [ "$(stat -t /data/*.sql >/dev/null 2>&1 && echo $?)" ]; then

	    DATA_PATH=$(find /data/*.sql | head -n 1)
	    printf "=> Loading data backup from %s... " "$DATA_PATH"
	    sudo -u www-data wp db import "$DATA_PATH"
		printf "Done!\n"

	    # If SEARCH_REPLACE is set => Replace URLs
	    if [ "$SEARCH_REPLACE" != false ]; then

	        printf "=> Replacing URLs... "
	        BEFORE_URL=$(echo "$SEARCH_REPLACE" | cut -d ',' -f 1)
	        AFTER_URL=$(echo "$SEARCH_REPLACE" | cut -d ',' -f 2)
	        sudo -u www-data wp search-replace  "$BEFORE_URL" "$AFTER_URL"
			printf "Done!\n"

	    fi

	else
	    printf "%s\n" \
	        "=> No database backup found. Initializing new database..." " " \
	        "      DEFAULT DATABASE CREDENTIALS" \
	        "=========================================" \
	        " Site URL:       $([ "$AFTER_URL" ] && echo "$AFTER_URL" || echo localhost:8080)" \
	        " Site Title:     $DB_NAME" \
	        " Admin Username: root" \
	        " Admin Password: $DB_PASS" \
	        " Admin Email:    admin@${DB_NAME}.com" \
	        "=========================================" " "

	    sudo -u www-data wp core install
	fi

	printf "=> Database initialization completed sucessfully!\n"

else
    printf "=> Database '%s' exists. SKIPPING...\n" "$DB_NAME"
fi


# .htaccess
if [ ! -f /app/.htaccess ]; then
	printf "=> Generating .htaccess file... "
	sudo -u www-data wp rewrite flush --hard
	printf "Done!\n"
else
	printf "=> .htaccess exists. SKIPPING...\n"
fi


# Adjust Filesystem Permissions
printf "=> Adjusting filesystem permissions... "
groupadd -f docker && usermod -aG docker www-data
find /app -type d -exec chmod 755 {} \;
find /app -type f -exec chmod 644 {} \;
chmod -R 775 /app/wp-content/uploads \
    && chown -R :docker /app/wp-content/uploads
printf "Done!\n"

# Install Plugins
[ "$PLUGINS" ] && \
	while IFS=',' read -ra plugin; do
        for i in "${!plugin[@]}"; do
            sudo -u www-data wp plugin is-installed "${plugin[$i]}"
            if [ $? -eq 0 ]; then
                printf "=> ($((i+1))/${#plugin[@]}) Plugin '%s' already installed. SKIPPING...\n" "${plugin[$i]}"
            else
                printf "=> ($((i+1))/${#plugin[@]}) Installing plugin: %s\n" "${plugin[$i]}"
                sudo -u www-data wp plugin install "${plugin[$i]}"
            fi
        done
    done <<< "$PLUGINS"

# Temp workaround until --ignore-plugins & --ignore-themes is fixed on wp-cli
[ -d /app/wp-content/plugins/akismet ] && \
	printf "=> Removing default plugins... "
	wp plugin uninstall akismet hello --deactivate --allow-root
	printf "Done!\n"

[ -d /app/wp-content/themes/twentyfifteen ] && \
	printf "=> Removing default themes... "
	wp theme delete twentyfifteen twentyfourteen --allow-root
	printf "Done!\n"

printf "=> WordPress configuration finished!\n"

source /etc/apache2/envvars
exec apache2 -D FOREGROUND
