#!/bin/bash

###
# ENVIRONMENT VARIABLES
##

# Build
LOCALHOST=${LOCALHOST:-false}
[[ "$SEARCH_REPLACE" ]] && \
  BEFORE_URL=${SEARCH_REPLACE%%,*} &&
  AFTER_URL=${SEARCH_REPLACE##*,}

# PHP
PHP_VERSION=${PHP_VERSION:-5.6} && \
  case $PHP_VERSION in
    5.6 | 7.0)
      ;;
    *)
      ERROR $LINENO "Invalid PHP version. (Must be 7.0 or 5.6)"
      ;;
  esac

# Database
DB_NAME=${DB_NAME:-wordpress}
DB_USER=${DB_USER:-root}
[[ ! "$DB_PASS" ]] && ERROR $LINENO "Environment variable 'DB_PASS' must be set"

# WordPress
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@$DB_NAME.com"}
SITE_NAME=${SITE_NAME:-wordpress} && \
  if [[ $SITE_NAME == 'wordpress' && $LOCALHOST != true ]]; then
    ERROR $(($LINENO-2)) "SITE_NAME must be set if not running on localhost"
  fi
THEMES=${THEMES:-twentysixteen}
WP_DEBUG_DISPLAY=${WP_DEBUG_DISPLAY:-true}
WP_DEBUG_LOG=${WP_DEBUG_LOG:-false}
WP_DEBUG=${WP_DEBUG:-false}


###
# Main Function
##

main() {

  # If no site directory exists, then this must be the initial installation
  if [ ! -e /var/www/$SITE_NAME/htdocs/wp-config.php ]; then
    initialize
  else
    h1 "Restarting containers from stopped state"
  fi

  # Be sure MySQL is ready for connections at this point
  echo -en "${ORANGE}${BOLD}==>${NC}${BOLD} Waiting for MySQL to initialize...."
  while ! mysqladmin ping --host=db --password=$DB_PASS &>/dev/null; do
    sleep 1
  done
  echo -e "Ready!${NC}"

  check_plugins

  # Garbage collect on initial build
  if [ -d /var/www/$SITE_NAME/htdocs/wp-content/plugins/akismet ]; then
    wordpress_init
  fi

  h2 "Adjusting filesystem permissions"
  h3 "Setting directory permissions to 755"
  find /var/www/$SITE_NAME -type d -exec chmod 755 {} \; 2>/dev/null
  STATUS
  h3 "Setting file permissions to 644"
  find /var/www/$SITE_NAME -type f -exec chmod 644 {} \; 2>/dev/null
  STATUS

  h2 "Restarting PHP-FPM"
  /etc/init.d/php$PHP_VERSION-fpm restart &>/dev/null
  h2 "Starting NGINX in the foreground"
  h1 "Setup complete!"
  exec nginx -g "daemon off;"
}


###
# Separation of concerns
##

# Installs WordPress for the first time.
#
# This function is ran only if a folder named $SITE_NAME
# doesn't exist within /var/www
initialize() {
  local data_path factpid replacements

  h1 "Setting up site. (This can take up to 20 minutes)"
  dpkg-divert --local --rename --add /sbin/initctl &>/dev/null && ln -sf /bin/true /sbin/initctlq

  # EasyEngine is painfully slow. To ease the torture, serve up cat facts every minute :)
  cat_facts&
  factpid=$!

  h2 "Initializing"
  easyengine_init

  # Alright, enough screwing around. Kill the cat facts!
  h2 "Initialization complete! That's all for today's helping of cat facts!"
  kill $factpid
  wait $factpid 2>/dev/null

  h2 "Installing and configuring dependencies"

  h3 "Installing Adminer"
  ee stack install --adminer &>/dev/null
  STATUS

  h3 "Configuring Adminer login credentials"
  ee secure --auth $DB_USER $DB_PASS
  STATUS
  echo "     Adminer Username: $DB_USER"
  echo "     Adminer Password: $DB_PASS"
  echo "               Server: db"
  echo "             Database: $DB_NAME"

  h3 "Configuring WP-CLI"
  generate_config_for wp-cli
  STATUS

  h3 "Updating to WP-CLI nightly"
  wp cli update --nightly --yes --allow-root
  STATUS

  h3 "Configuring PHP-FPM"
  generate_config_for php-fpm
  STATUS

  if [[ "$LOCALHOST" == true ]]; then
    if [[ $AFTER_URL =~ (https?://)?(www.)?(.+):[0-9]{2,4} ]]; then
      h3 "Adjusting NGINX for localhost"
      sed -i "s!server_name.*;!server_name ${BASH_REMATCH[3]};!" /etc/nginx/sites-enabled/$SITE_NAME
      STATUS
    else
      h3 "Adjusting NGINX for localhost"
      sed -i "s/server_name.*;/server_name localhost;/" /etc/nginx/sites-enabled/$SITE_NAME
      STATUS
    fi
  fi

  if [[ "$PHP_VERSION" == 7.0 ]]; then
    h3 "Adjusting NGINX confs on port 22222 for PHP 7"
    generate_config_for php7-22222
    STATUS
  fi

  h3 "Adjusting filesystem ownership"
  chown -R www-data:www-data /var/www
  STATUS

  h2 "Configuring WordPress"
  h3 "Generating wp-config.php"
  WP core config
  STATUS

  h3 "Setting up database"
  WP db create &>/dev/null
  STATUS

  # If an SQL file exists in /data => load it
  if [ "$(stat -t /data/*.sql &>/dev/null && echo $?)" ]; then
    data_path=$(find /data/*.sql | head -n 1)
    h2 "Loading data backup from $data_path"
    h3 "Importing data backup"
    WP db import "$data_path" &>/dev/null
    STATUS

    # If SEARCH_REPLACE is set => Replace URLs
    if [[ "$SEARCH_REPLACE" ]]; then
      h3 "Replacing URLs in database"
      replacements=$(WP search-replace --no-quiet "$BEFORE_URL" "$AFTER_URL" --skip-columns=guid | tail -1 | awk '{print $3}')
      STATUS
      h2 "$replacements replacements made in database"
    fi
  else
    h3 "No database backup found. Initializing new database"
    WP core install &>/dev/null
    STATUS
  fi

  file_cleanup

  h2 "Initial setup complete!"
}

# Still pretty featureless, but this will be used to create the build string
easyengine_init() {
  local options="$SITE_NAME --wpfc "

  [[ $PHP_VERSION == 7.0 ]] && options+='--php7 '
  [[ $LOCALHOST != true ]]&& options+='--letsencrypt'

  h2 "Installing WordPress Stack for $SITE_NAME"
  printf "    | %s\n" \
    "   PHP Version: $PHP_VERSION" \
    "    Cache Type: NGINX fastcgi" \
    "SSL Encryption: $([[ $LOCALHOST == true ]] && echo 'Disabled' || echo 'Enabled')"

  yes 'y' | LC_ALL=en_US.UTF-8 ee site create $options &>/dev/null

}

# Sweeps through the $PLUGINS list to make sure all that required get installed
# If 'rest-api' plugin is requested, then the restful WP-CLI addon is also installed.
check_plugins() {
  local plugin_name

  if [ ! "$PLUGINS" ]; then
    h2 "No plugin dependencies listed. SKIPPING"
    return
  fi

  h2 "Checking Plugins..."
  while IFS=',' read -ra plugin; do
    for i in "${!plugin[@]}"; do
      plugin_name=$(echo "${plugin[$i]}" | xargs)
      plugin_url=

      # If plugin matches a URL
      if [[ $plugin_name =~ ^https?://[www]?.+ ]]; then
        echo $plugin_name 'matches URL'
        h3 "Can't check if plugin is already installed using this format!" && STATUS SKIP
        h3 "Switch your compose file to [plugin-slug]http://pluginurl.com for better checks" && STATUS SKIP
        h3 "($((i+1))/${#plugin[@]}) '$plugin_name' not found. Installing"
        WP plugin install "$plugin_name"
        STATUS
        continue
      fi

      # If plugin matches a URL in new URL format
      if [[ $plugin_name =~ ^\[.+\]https?://[www]?.+ ]]; then
        plugin_url=${plugin_name##\[*\]}
        plugin_name="$(echo $plugin_name | grep -oP '\[\K(.+)(?=\])')"
      fi

      plugin_url=${plugin_url:-$plugin_name}

      WP plugin is-installed "$plugin_name"
      if [ $? -eq 0 ]; then
        h3 "($((i+1))/${#plugin[@]}) '$plugin_name' found. SKIPPING"
        STATUS SKIP
      else
        h3 "($((i+1))/${#plugin[@]}) '$plugin_name' not found. Installing"
        WP plugin --activate install "$plugin_url"
        STATUS
        if [ $plugin_name == 'rest-api' ]; then
          h3 "Installing 'restful' WP-CLI package"
          wp package install wp-cli/restful --allow-root
          STATUS
        fi
      fi
    done
  done <<< "$PLUGINS"
}

# Removes bundled plugins and themes that aren't needed.
# Installs themes that ARE needed.
# note: This function only runs on the initial build (not restarts)
wordpress_init() {
  h3 "Removing default plugins"
  WP plugin uninstall akismet hello --deactivate
  STATUS

  h3 "Removing unneeded themes"
  local remove_list=(twentyfourteen twentyfifteen twentysixteen)
  local theme_list=()
  while IFS=',' read -ra theme; do
    for i in "${!theme[@]}"; do
      remove_list=( "${remove_list[@]/${theme[$i]}}" )
      theme_list+=("${theme[$i]}")
    done
    WP theme delete "${remove_list[@]}"
    STATUS
  done <<< $THEMES

  h3 "Installing needed themes"
  WP theme install "${theme_list[@]}"
  STATUS
}

file_cleanup() {

  local purges='--mysql '
  local purgemsg="Purging: MySQL"

  [[ $PHP_VERSION == 7.0 ]] && purges+='--php ' && purgemsg+=', PHP 5.6 '

  h2 "Removing unneeded build dependencies"

  h3 "$purgemsg"
  yes 'yes' | ee stack purge $purges &>/dev/null
  STATUS

  # TODO: Keep adding to this list
  h3 "Removing unneeded system packages"
  DEBIAN_FRONTEND=noninteractive apt-get remove -yqq --purge --auto-remove \
    manpages \
    manpages-dev \
  &>/dev/null
  STATUS

  h3 "Clearing apt-cache"
  rm -rf /var/lib/apt/lists/*
  STATUS
}

###
# Configurations
##

generate_config_for() {

case "$1" in

wp-cli)
cat > /wp-cli.yml <<EOF
path: /var/www/$SITE_NAME/htdocs
quiet: true

core config:
  dbuser: $DB_USER
  dbpass: $DB_PASS
  dbname: $DB_NAME
  dbhost: db
  extra-php: |
    define( 'WP_DEBUG', $WP_DEBUG );
    define( 'WP_DEBUG_LOG', $WP_DEBUG_LOG );
    define( 'WP_DEBUG_DISPLAY', $WP_DEBUG_DISPLAY );

core install:
  url: $([ "$AFTER_URL" ] && echo "$AFTER_URL" || echo localhost:8080)
  title: $SITE_NAME
  admin_user: $DB_USER
  admin_password: $DB_PASS
  admin_email: $ADMIN_EMAIL
  skip-email: true
EOF
;;

php-fpm)
mkdir -p /run/php
cat > /etc/php/$PHP_VERSION/fpm/php-fpm.conf <<EOF
[global]
daemonize = no
pid = /run/php/php$PHP_VERSION-fpm.pid
error_log = /var/log/php/$PHP_VERSION/fpm.log
log_level = notice
include = /etc/php/$PHP_VERSION/fpm/pool.d/*.conf
EOF
;;

php7-22222)
cat > /etc/nginx/sites-available/22222 <<EOF
# EasyEngine admin NGINX CONFIGURATION
# Adjusted for PHP 7

server {

  listen 22222 default_server ssl http2;

  access_log   /var/log/nginx/22222.access.log rt_cache;
  error_log    /var/log/nginx/22222.error.log;

  ssl_certificate /var/www/22222/cert/22222.crt;
  ssl_certificate_key /var/www/22222/cert/22222.key;

  # Force HTTP to HTTPS
  error_page 497 =200 https://\$host:22222\$request_uri;

  root /var/www/22222/htdocs;
  index index.php index.htm index.html;

  # Turn on directory listing
  autoindex on;

  # HTTP Authentication on port 22222
  include common/acl.conf;
  include common/php7.conf;
  include common/locations-php7.conf;
  include /var/www/22222/conf/nginx/*.conf;

}
EOF
;;

esac

}

###
# Cat Facts! Because, why not? (also because easyengine is painfully slow)
##

cat_facts() {
  local fact
  sleep 5
  h2 "While you wait, enjoy 1 complementary cat fact per minute."
  sleep 1.5
  while [[ true ]]; do
    fact=$(curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET http://catfacts-api.appspot.com/api/facts | grep -oP '\["\K(.+)(?="\])')
    CF $fact
    sleep 60
  done
}

CF() {
  echo -e "${PINK}${BOLD}≧◔◡◔≦${NC} $*" | sed -e 's/\\//g'
}


###
# HELPERS
##

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
PURPLE='\033[0;34m'
PINK='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\E[1m'
NC='\033[0m'

h1() {
  local len=$(($(tput cols)-1))
  local input=$*
  local size=$((($len - ${#input})/2))

  for ((i = 0; i < $len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo ""
  for ((i = 0; i < $size; i++)); do echo -n " "; done; echo -e "${NC}${BOLD}$input"
  for ((i = 0; i < $len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo -e "${NC}"
}

h2() {
  echo -e "${ORANGE}${BOLD}==>${NC}${BOLD} $*${NC}"
}

h3() {
  local width msg msglen
  width=$(($(tput cols)-10))
  msg=$*
  msglen=$((${#msg}+13))
  printf "%b" "${CYAN}${BOLD}  ->${NC} $msg"
  for ((i = 0; i < $(($width - $msglen)); i++)); do echo -ne " "; done;
}

STATUS() {
  local status=$?
  if [[ $1 == 'SKIP' ]]; then
    echo ""
    return
  fi
  if [[ $status != 0 ]]; then
    echo -e "${RED}[FAILED]${NC}"
    return
  fi
  echo -e "${GREEN}[PASSED]${NC}"
}

ERROR() {
  echo -e "${RED}=> ERROR (Line $1): $2.${NC}";
  exit 1;
}

WP() {
  sudo -u www-data wp "$@"
}

main
