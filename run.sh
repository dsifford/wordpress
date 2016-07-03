#!/bin/bash

###
# GLOBALS
##
PHP_VERSION=5.6

###
# ENVIRONMENT VARIABLES
##

# Required
[[ ! "$DB_PASS" ]] && ERROR $LINENO "Environment variable 'DB_PASS' must be set"

# Optional, with defaults
DB_NAME=${DB_NAME:-wordpress}
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@$DB_NAME.com"}
LOCALHOST=${LOCALHOST:-false}
SITE_NAME=${SITE_NAME:-wordpress}
THEMES=${THEMES:-twentysixteen}
WP_DEBUG_DISPLAY=${WP_DEBUG_DISPLAY:-true}
WP_DEBUG_LOG=${WP_DEBUG_LOG:-false}
WP_DEBUG=${WP_DEBUG:-false}

# Optional, no defaults
[[ "$SEARCH_REPLACE" ]] && \
  BEFORE_URL=${SEARCH_REPLACE%%,*} &&
  AFTER_URL=${SEARCH_REPLACE##*,}


###
# Configurations
##

wp_cli_config() {
cat > /wp-cli.yml <<EOF
path: /var/www/$SITE_NAME/htdocs
quiet: true

core config:
  dbuser: root
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
  admin_user: root
  admin_password: $DB_PASS
  admin_email: $ADMIN_EMAIL
  skip-email: true
EOF
}

php_fpm_config() {
mkdir -p /run/php
cat > /etc/php/$PHP_VERSION/fpm/php-fpm.conf <<EOF
[global]
daemonize = no
pid = /run/php/php$PHP_VERSION-fpm.pid
error_log = /var/log/php/$PHP_VERSION/fpm.log
log_level = notice
include = /etc/php/$PHP_VERSION/fpm/pool.d/*.conf
EOF
}

main() {

  # If no site directory exists, then this must be the initial installation
  if [ ! -d /var/www/$SITE_NAME/htdocs/wp-content/plugins/akismet ]; then
    initialize
  fi

  # Be sure MySQL is ready for connections at this point
  echo -en "${ORANGE}=> Waiting for MySQL to initialize...."
  while ! mysqladmin ping --host=db --password=$DB_PASS &>/dev/null; do
    sleep 1
  done
  echo -e "Ready!${NC}"

  check_plugins

  # Garbage collect on initial build
  if [ -d /var/www/$SITE_NAME/htdocs/wp-content/plugins/akismet ]; then
    wordpress_init
  fi

  h3 "Adjusting filesystem permissions"
  find /app -type d -exec chmod 755 {} \;
  find /app -type f -exec chmod 644 {} \;
  STATUS

  h1 "Setup complete!"
  h2 "Restarting PHP-FPM"
  /etc/init.d/php$PHP_VERSION-fpm restart &>/dev/null
  h2 "Starting NGINX in the foreground"
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
  local data_path factpid

  h1 "Setting up site. (This can take up to 20 minutes)"
  dpkg-divert --local --rename --add /sbin/initctl &>/dev/null && ln -sf /bin/true /sbin/initctlq

  # EasyEngine is painfully slow. To ease the torture, serve up cat facts every minute :)
  cat_facts&
  factpid=$!

  h2 "Initializing"
  LC_ALL=en_US.UTF-8 ee site create ${SITE_NAME:-wordpress} --wpfc &>/dev/null

  # Alright, enough screwing around. Kill the cat facts!
  h2 "Initialization complete! That's all for today's helping of cat facts!"
  kill $factpid &>/dev/null

  h2 "Installing and configuring dependencies"
  h3 "Installing Adminer"
  ee stack install --adminer &>/dev/null
  STATUS

  h3 "Configuring WP-CLI"
  wp_cli_config
  STATUS

  h3 "Updating to WP-CLI nightly"
  wp cli update --nightly --yes --allow-root
  STATUS

  h3 "Configuring PHP-FPM"
  php_fpm_config
  STATUS

  if [[ "$LOCALHOST" == 'true' ]]; then
    h3 "Adjusting NGINX for localhost"
    sed -i "s/server_name.*;/server_name localhost;/" /etc/nginx/sites-enabled/$SITE_NAME
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
      WP search-replace "$BEFORE_URL" "$AFTER_URL" --skip-columns=guid
      STATUS
    fi
  else
    h3 "No database backup found. Initializing new database"
    WP core install &>/dev/null
    STATUS
  fi

  h2 "Removing unneeded build dependencies"
  h3 "Removing MySQL server"
  yes 'yes' | ee stack remove --mysql &>/dev/null
  STATUS
  h3 "Clearing apt-cache"
  rm -rf /var/lib/apt/lists/*
  STATUS

  h2 "Initial setup complete!"
}

# Sweeps through the $PLUGINS list to make sure all that required get installed
# If 'rest-api' plugin is requested, then the wp-rest-cli WP-CLI addon is also installed.
check_plugins() {
  local plugin_name

  if [ ! "$PLUGINS" ]; then
    h2 "No plugin dependencies listed. SKIPPING"
    return
  fi

  h2 "Checking plugins"
  while IFS=',' read -ra plugin; do
    for i in "${!plugin[@]}"; do
      plugin_name=$(echo "${plugin[$i]}" | xargs)
      WP plugin is-installed "$plugin_name"
      if [ $? -eq 0 ]; then
        h3 "($((i+1))/${#plugin[@]}) '$plugin_name' found. SKIPPING"
        STATUS SKIP
      else
        h3 "($((i+1))/${#plugin[@]}) '$plugin_name' not found. Installing"
        WP plugin install "$plugin_name"
        STATUS
        if [ $plugin_name == 'rest-api' ]; then
          h3 "Plugin 'rest-api' found. Installing 'wp-rest-cli' WP-CLI package"
          wp package install danielbachhuber/wp-rest-cli --allow-root
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

cat_facts() {
  local fact
  h2 "While you wait, enjoy 1 free cat fact per minute."
  sleep 1.5
  while [[ true ]]; do
    fact=$(curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET http://catfacts-api.appspot.com/api/facts | grep -Po '(?<="facts": \[")(.+?)"')
    CF "${fact::-1}"
    sleep 60
  done
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

CF() {
  echo -e "${PINK}${BOLD}≧◔◡◔≦${NC} $*"
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