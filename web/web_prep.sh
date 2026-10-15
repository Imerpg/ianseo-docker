#!/bin/bash

# ============================================================
#  web_prep.sh — Ianseo preparation and startup script
# ============================================================

# Stop script on any error
set -e

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
IANSEO_VERSION="${IANSEO_VERSION}"
IANSEO_ZIP="/tmp/Ianseo_${IANSEO_VERSION}.zip"
INSTALL_DIR="/var/www/html/ianseo"
INDEX_PHP="$INSTALL_DIR/Install/index.php"
CONFIG_FILE="$INSTALL_DIR/Common/config.inc.php"
DB_HOST="${DB_HOST:-ianseo-install-db-1}"
# ------------------------------------------------------------


# ------------------------------------------------------------
# directory_prep — Prepare the installation directory
# ------------------------------------------------------------
directory_prep()
{
    echo "==> Preparing installation directory..."
    mkdir -p "$INSTALL_DIR"
}
# ------------------------------------------------------------


# ------------------------------------------------------------
# download_ianseo — Download the Ianseo archive
#   (version defined in the .env file)
# ------------------------------------------------------------
download_ianseo()
{
    # Only download if Ianseo is not already installed
    if [ -f "$INSTALL_DIR/index.php" ]; then
        echo "[OK] Ianseo already installed, skipping download."
        return 0
    fi

    if [ -f "$IANSEO_ZIP" ]; then
        echo "[OK] Archive already downloaded."
        return 0
    fi

    echo "==> Downloading Ianseo version ${IANSEO_VERSION}..."

    # -f: fail on HTTP errors (404, 500...) instead of
    #     saving an empty error page
    if ! curl -fL "https://ianseo.net/Release/Ianseo_${IANSEO_VERSION}.zip" -o "$IANSEO_ZIP"; then
        echo "[ERROR] Failed to download the Ianseo ZIP file." >&2
        exit 1
    fi

    # Check: make sure the downloaded file is not empty
    if [ ! -s "$IANSEO_ZIP" ]; then
        echo "[ERROR] The downloaded file is empty or corrupted." >&2
        exit 1
    fi

    echo "[OK] Download completed."
}
# ------------------------------------------------------------


# ------------------------------------------------------------
# extract_ianseo_zip — Extract the ZIP archive
# ------------------------------------------------------------
extract_ianseo_zip()
{
    if [ ! -f "$INSTALL_DIR/index.php" ]; then
        echo "==> Extracting ${IANSEO_ZIP}..."

        # Make sure the extraction succeeds
        if ! unzip -q "$IANSEO_ZIP" -d "$INSTALL_DIR"; then
            echo "[ERROR] Failed to extract the Ianseo ZIP file." >&2
            exit 1
        fi

        rm -f "$IANSEO_ZIP"
        echo "[OK] Extraction completed."
    fi
}
# ------------------------------------------------------------


# ------------------------------------------------------------
# ianseo_tweaks — Apply post-installation patches
#   1. Set the database host in index.php
#   2. Fix a known typo in UpdateDb.inc.php
#      (only if the MD5 checksum matches)
# ------------------------------------------------------------
ianseo_tweaks()
{
    # 1. Set the database host in index.php
    if [ -f "$INDEX_PHP" ]; then
        echo "==> Modifying ${INDEX_PHP}..."
        if ! sed -i.orig "s/W_HOST='localhost'/W_HOST='${DB_HOST}'/" "$INDEX_PHP"; then
            echo "[ERROR] Could not set the database host in index.php." >&2
            exit 1
        fi
        echo "[OK] index.php updated."
    else
        echo "[ERROR] File ${INDEX_PHP} not found." >&2
        exit 1
    fi

    # 2. Fix the known typo in UpdateDb.inc.php
    UPDATE_DB_FILE="$INSTALL_DIR/Common/UpdateDb.inc.php"
    if [ -f "$UPDATE_DB_FILE" ]; then
        UPDATE_DB_MD5SUM=$(md5sum "$UPDATE_DB_FILE" | awk '{ print $1 }')
        if [ "$UPDATE_DB_MD5SUM" = "9b97ce0acf64cdd6df6dadfd5e72bead" ]; then
            echo "==> Applying patch to UpdateDb.inc.php..."
            if ! sed -i 's/if($u=safe_fetch($q))/if($u=safe_fetch($t))/' "$UPDATE_DB_FILE"; then
                echo "[ERROR] Failed to apply the UpdateDb.inc.php patch." >&2
                exit 1
            fi
            echo "[OK] Patch applied."
        fi
    fi
}
# ------------------------------------------------------------


# ------------------------------------------------------------
# set_permissions — Set file permissions
#   (as required by the Ianseo installation docs)
# ------------------------------------------------------------
set_permissions()
{
    echo "==> Adjusting ownership and permissions..."

    # Owner: www-data
    if ! chown -R www-data:www-data "$INSTALL_DIR"; then
        echo "[ERROR] Failed to chown ${INSTALL_DIR} to www-data." >&2
        exit 1
    fi

    # Write permissions
    if ! chmod -R u+wX "$INSTALL_DIR"; then
        echo "[ERROR] Failed to set permissions on ${INSTALL_DIR}." >&2
        exit 1
    fi

    echo "[OK] Permissions adjusted."
}
# ------------------------------------------------------------


# ------------------------------------------------------------
# update_ianseo — Update and install Ianseo
#   (initial SQL schema, replaces the web installer)
# ------------------------------------------------------------
update_ianseo() {
    echo "==> Checking Ianseo database..."

    # Wait for the database server to be ready (max ~30s)
    DB_READY=0
    for i in $(seq 1 30); do
        if mysqladmin ping -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl > /dev/null 2>&1; then
            DB_READY=1
            break
        fi
        echo "    Waiting for database... (${i}/30)"
        sleep 1
    done

    if [ "$DB_READY" -ne 1 ]; then
        echo "[ERROR] Database server ${DB_HOST} is not reachable." >&2
        exit 1
    fi

    # Check whether the schema is already installed
    TABLE_EXISTS=$(mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl \
        "${MYSQL_DATABASE}" -N -e "SHOW TABLES LIKE 'Parameters';" 2>/dev/null | wc -l) || TABLE_EXISTS=0

    # Import the initial SQL schema only if the database is empty
    if [ "${TABLE_EXISTS:-0}" -eq 0 ]; then
        echo "==> Database is empty, importing initial SQL schema..."
        if [ -f "$INSTALL_DIR/Install/install.sql" ]; then
            if ! mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" \
                < "$INSTALL_DIR/Install/install.sql"; then
                echo "[ERROR] Failed to import install.sql into the database." >&2
                exit 1
            fi
            echo "[OK] Database installed successfully."
        else
            echo "[ERROR] install.sql not found in $INSTALL_DIR/Install/" >&2
            exit 1
        fi
    else
        echo "[OK] Database already initialized — nothing to do."
    fi
}
# ------------------------------------------------------------

# ------------------------------------------------------------
# generate_config — Generate the Ianseo configuration
#   (bypasses the manual web installation)
#   1. Root config.php (prevents "Undefined property" errors)
#   2. Common/config.inc.php (expected by the application)
# ------------------------------------------------------------
generate_config()
{
    # 1. Root config.php
    ROOT_CONFIG="$INSTALL_DIR/config.php"
    if [ ! -f "$ROOT_CONFIG" ]; then
        echo "==> Creating root configuration file config.php..."
        cat << EOF > "$ROOT_CONFIG"
<?php
\$CFG = new stdClass();
\$CFG->DOCUMENT_PATH = '$INSTALL_DIR/';
\$CFG->ROOT_DIR = '/ianseo/';
\$CFG->DB_NAME = '${MYSQL_DATABASE}';
\$CFG->W_HOST = '${DB_HOST}';
\$CFG->W_USER = '${MYSQL_USER}';
\$CFG->W_PASS = '${MYSQL_PASSWORD}';
\$CFG->R_HOST = '${DB_HOST}';
\$CFG->R_USER = '${MYSQL_USER}';
\$CFG->R_PASS = '${MYSQL_PASSWORD}';
\$CFG->TRACE_QUERIES = false;
?>
EOF
        chown www-data\:www-data "$ROOT_CONFIG"
    fi

    # 2. Common/config.inc.php (expected by the application)
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "==> Creating Common/config.inc.php..."
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
        chown www-data\:www-data "$CONFIG_FILE"
    fi

    echo "[OK] Configuration files created."
}
# ------------------------------------------------------------


# ============================================================
#  Main script
# ============================================================
echo "==> Starting web_prep script..."

directory_prep
download_ianseo
extract_ianseo_zip
ianseo_tweaks
set_permissions
update_ianseo
generate_config

# Debug preparation (only if the file exists in /tmp)
if [ -f /tmp/phpinfo.php ]; then
    echo "==> Enabling phpinfo.php debug file..."
    cp /tmp/phpinfo.php /var/www/html/phpinfo.php
    chown www-data:www-data /var/www/html/phpinfo.php
fi

# Enable Apache configuration
# (no reload needed: Apache is started afterwards by apache2-foreground)
a2enconf ianseo > /dev/null 2>&1 || true

echo "[OK] web_prep script completed."
echo "==> Starting application..."
exec apache2-foreground