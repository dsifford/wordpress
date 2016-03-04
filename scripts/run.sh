#!/bin/bash

if [ ! -f /app/wp-config.php ]; then
    /app/init-wp
fi


if [ ! -f /.mysql_db_created ]; then
    /app/init-db
fi


source /etc/apache2/envvars
exec apache2 -D FOREGROUND
