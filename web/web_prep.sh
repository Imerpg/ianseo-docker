#!/bin/bash

# Stop script on any error
set -e

# ------------------------------------
# Variables
# ------------------------------------
IANSEO_VERSION="${IANSEO_VERSION}"
IANSEO_ZIP="/tmp/Ianseo_${IANSEO_VERSION}.zip"
INSTALL_DIR="/var/www/html/ianseo"
INDEX_PHP="$INSTALL_DIR/Install/index.php"
CONFIG_FILE="$INSTALL_DIR/Common/config.inc.php"
DB_HOST="${DB_HOST:-ianseo-install-db-1}"
# ------------------------------------



# -------------------------------------
# Prepare le répértoire d'installation
# -------------------------------------
directory_prep()
{
    echo "Préparation du répertoire d'installation..."
    mkdir -p "$INSTALL_DIR"
}
# ------------------------------------



# ------------------------------------
# Télécharge Ianseo daté de la date indiqué dans .env
# ------------------------------------
download_ianseo()
{
    if [ ! -f "$IANSEO_ZIP" ]; then
        echo "Téléchargement d'Ianseo version ${IANSEO_VERSION} depuis le site officiel..."

        # curl -f permet de renvoyer une erreur HTTP (ex: 404 ou 500) au lieu de télécharger une page d'erreur vide
        if ! curl -fL "https://ianseo.net/Release/Ianseo_${IANSEO_VERSION}.zip" -o "$IANSEO_ZIP"; then
            echo "ERREUR : Échec du téléchargement du fichier ZIP d'Ianseo." >&2
            exit 1
        fi

        # Vérification supplémentaire : s'assurer que le fichier téléchargé n'est pas vide
        if [ ! -s "$IANSEO_ZIP" ]; then
            echo "ERREUR : Le fichier téléchargé est vide ou corrompu." >&2
            exit 1
        fi

        echo "Téléchargement terminé avec succès."
    fi
}
# ------------------------------------



# ------------------------------------
# Extration du zip
# ------------------------------------
extract_ianseo_zip()
{
    # On vérifie si index.php n'existe pas déjà pour éviter de réextraire à chaque redémarrage
    if [ ! -f "$INSTALL_DIR/index.php" ]; then
        echo -n "Extraction du fichier $IANSEO_ZIP... "
        unzip -q "$IANSEO_ZIP" -d "$INSTALL_DIR"
        rm -f "$IANSEO_ZIP"
        echo "fait."
    fi
}
# ------------------------------------



# ------------------------------------
# Ianseo tweaks
# ------------------------------------
ianseo_tweaks()
{
    # Configure l'hôte de base de données dans index.php si besoin
    if [ -f "$INDEX_PHP" ]; then
        echo "Modification de ${INDEX_PHP}"
        sed -i.orig "s/W_HOST='localhost'/W_HOST='${DB_HOST}'/" "$INDEX_PHP"
    fi

    # Fix a known typo in UpdateDb.inc.php si le fichier correspond au checksum
    UPDATE_DB_FILE="$INSTALL_DIR/Common/UpdateDb.inc.php"
    if [ -f "$UPDATE_DB_FILE" ]; then
        UPDATE_DB_MD5SUM=$(md5sum "$UPDATE_DB_FILE" | awk '{ print $1 }')
        if [ "$UPDATE_DB_MD5SUM" = "9b97ce0acf64cdd6df6dadfd5e72bead" ]; then
            echo "Correction du bug dans UpdateDb.inc.php."
            sed -i 's/if($u=safe_fetch($q))/if($u=safe_fetch($t))/' "$UPDATE_DB_FILE"
        fi
    fi
}
# ------------------------------------



# ------------------------------------
# Définie les premision (voir instalation Ianseo)
# ------------------------------------
set_permissions()
{
    echo "Ajustement des permissions et des propriétaires."
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R u+wX "$INSTALL_DIR"
}
# ------------------------------------



# ------------------------------------
# Met a jour et installe ianseo (même l'installation web !)
# ------------------------------------
update_ianseo() {
    echo "==> Vérification de la base de données Ianseo..."

    TABLE_EXISTS=$(mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" \
        -e "SHOW TABLES LIKE 'Parameters';" 2>/dev/null | grep -c "Parameters") || TABLE_EXISTS=0

    # Importation du schéma SQL initial uniquement si la base est totalement vide
    if [ "${TABLE_EXISTS:-0}" -eq 0 ]; then
        echo "==> Importation du schéma SQL initial..."
        if [ -f "$INSTALL_DIR/Install/install.sql" ]; then
            mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" \
                < "$INSTALL_DIR/Install/install.sql"
            echo "==> Importation SQL terminée."
        else
            echo "ERREUR : Fichier install.sql introuvable dans $INSTALL_DIR/Install/"
            exit 1
        fi
    else
        echo "==> La base de données est déjà initialisée, importation ignorée."
    fi
}
# ------------------------------------



# ------------------------------------
# Génére la configuration de Ianseo (bypass l'installation manuelle)
# ------------------------------------
generate_config()
{
    # 1. Créer le fichier config.php à la racine d'Ianseo (celui qui lève les erreurs Undefined property)
    ROOT_CONFIG="$INSTALL_DIR/config.php"
    if [ ! -f "$ROOT_CONFIG" ]; then
        echo "Création du fichier de configuration racine config.php..."
        cat << EOF > "$ROOT_CONFIG"
<?php
if (!defined('INSTALL')) {
    // Si appelé directement, charge les bases
}
$CFG = new stdClass();
$CFG->DOCUMENT_PATH = '$INSTALL_DIR/';
$CFG->ROOT_DIR = '/ianseo/';
$CFG->DB_NAME = '${MYSQL_DATABASE}';
$CFG->W_HOST = '${DB_HOST}';
$CFG->W_USER = '${MYSQL_USER}';
$CFG->W_PASS = '${MYSQL_PASSWORD}';
$CFG->R_HOST = '${DB_HOST}';
$CFG->R_USER = '${MYSQL_USER}';
$CFG->R_PASS = '${MYSQL_PASSWORD}';
$CFG->TRACE_QUERIES = false;
?>
EOF
        chown www-data:www-data "$ROOT_CONFIG"
    fi

    # 2. Créer le fichier Common/config.inc.php attendu par l'application
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Création du fichier de configuration Common/config.inc.php..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat << EOF > "$CONFIG_FILE"
<?php
// settings for the READ server
\$CFG->R_HOST = '${DB_HOST}';
\$CFG->R_USER = '${MYSQL_USER}';
\$CFG->R_PASS = '${MYSQL_PASSWORD}';

// settings for the WRITE Server
\$CFG->W_HOST = '${DB_HOST}';
\$CFG->W_USER = '${MYSQL_USER}';
\$CFG->W_PASS = '${MYSQL_PASSWORD}';

/* DB Name */
\$CFG->DB_NAME = '${MYSQL_DATABASE}';

// set the root directory
\$CFG->ROOT_DIR = '/ianseo/';
\$CFG->DOCUMENT_PATH = '$INSTALL_DIR/';
?>
EOF
        chown www-data:www-data "$CONFIG_FILE"
        echo "Fichiers de configuration créés avec succès."
    fi
}
# ------------------------------------



# ------------------------------------
# Script pricipal
# ------------------------------------
echo "web_prep script starting:"
directory_prep
download_ianseo
extract_ianseo_zip
ianseo_tweaks
set_permissions
update_ianseo
generate_config

# Préparation du debug (si le fichier existe dans /tmp)
if [ -f /tmp/phpinfo.php ]; then
    cp /tmp/phpinfo.php /var/www/html/phpinfo.php
    chown www-data:www-data /var/www/html/phpinfo.php
fi

# Activation config Apache
a2enconf ianseo || true

echo "web_prep script completed."

echo "Lancement de l'application ...."
exec apache2-foreground

# ------------------------------------