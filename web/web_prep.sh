#!/bin/bash

# Stop script on any error
set -e

# Variables
IANSEO_ZIP=/tmp/Ianseo_${IANSEO_VERSION}.zip
INSTALL_DIR=/var/www/html/ianseo
INDEX_PHP=$INSTALL_DIR/Install/index.php
CONFIG_FILE="$INSTALL_DIR/Common/config.inc.php"
DB_HOST="ianseo-install-db-1"

directory_prep()
{
    if [ ! -f $IANSEO_ZIP ]; then
        echo "Did not find required file $IANSEO_ZIP."
        exit 1
    fi

    if [ ! -d $INSTALL_DIR ]; then
        mkdir -p $INSTALL_DIR
    fi
}

extract_ianseo_zip()
{
    if [ ! -f "$INSTALL_DIR/index.php" ]; then
        echo -n "Extracting $IANSEO_ZIP file... "
        unzip -q $IANSEO_ZIP -d $INSTALL_DIR
        rm -f $IANSEO_ZIP
        echo "done."
    fi
}

ianseo_tweaks()
{

    # Check how the config file as create
    #generate_config

    # Configure l'hôte de base de données dans index.php si besoin
    if [ -f $INDEX_PHP ]; then
        echo "Tweaking ${INDEX_PHP}"
        sed -i.orig "s/W_HOST='localhost'/W_HOST='ianseo_docker_db'/" $INDEX_PHP
    fi

    # Fix a known typo in UpdateDb.inc.php si le fichier correspond au checksum
    UPDATE_DB_FILE=$INSTALL_DIR/Common/UpdateDb.inc.php
    if [ -f "$UPDATE_DB_FILE" ]; then
        UPDATE_DB_MD5SUM=$(md5sum "$UPDATE_DB_FILE" | awk '{ print $1 }')
        if [ "$UPDATE_DB_MD5SUM" = "9b97ce0acf64cdd6df6dadfd5e72bead" ]; then
            echo "Fixing typo in UpdateDb.inc.php."
            sed -i 's/if($u=safe_fetch($q))/if($u=safe_fetch($t))/' "$UPDATE_DB_FILE"
        fi
    fi
}

set_permissions()
{
    echo "Adjusting ianseo file ownership and access."
    chown -R www-data:www-data $INSTALL_DIR
    chmod -R u+wX $INSTALL_DIR
}

download_ianseo()
{
    if [ ! -f "$IANSEO_ZIP" ]; then
        echo "Downloading Ianseo version ${IANSEO_VERSION} from the official site..."
        curl -L "https://ianseo.net/Release/Ianseo_${IANSEO_VERSION}.zip" -o "$IANSEO_ZIP"
        echo "Download completed."
    fi
}

update_ianseo() {
    echo "==> Vérification de la base de données Ianseo..."
    TABLE_EXISTS=$(mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p "${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" -e "SHOW TABLES LIKE 'Parameters';" | grep -c "Parameters" || true)
    
    # Importation du schéma SQL initial uniquement si la base est totalement vide
    if [ "$TABLE_EXISTS" -eq 0 ]; then
        echo "==> Importation du schéma SQL initial..."
        mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" < "$INSTALL_DIR/Install/install.sql"
    else
        echo "==> La base de données est déjà initialisée, importation ignorée."
    fi

    echo "==> Étape de mise à jour PHP ignorée (sautée)."
}

generate_config()
{
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Création du fichier de configuration config.inc.php..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat << EOF > "$CONFIG_FILE"
<?php
\$CFG = new stdClass();
\$CFG->R_HOST = '${DB_HOST}';
\$CFG->R_USER = '${MYSQL_USER}';
\$CFG->R_PASS = '${MYSQL_PASSWORD}';
\$CFG->W_HOST = '${DB_HOST}';
\$CFG->W_USER = '${MYSQL_USER}';
\$CFG->W_PASS = '${MYSQL_PASSWORD}';
\$CFG->DB_NAME = '${MYSQL_DATABASE}';
?>
EOF
        echo "Fichier de configuration créé avec succès."
    fi
}

echo "web_prep script starting:"
download_ianseo
directory_prep
extract_ianseo_zip
ianseo_tweaks
set_permissions
update_ianseo

# Préparation du debug (si le fichier existe dans /tmp)
if [ -f /tmp/phpinfo.php ]; then
    cp /tmp/phpinfo.php /var/www/html/phpinfo.php
    chown www-data:www-data /var/www/html/phpinfo.php
fi

# Activation config Apache
a2enconf -q ianseo || true

echo "web_prep script completed."

echo "Lancement de l'application ...."
exec apache2-foreground