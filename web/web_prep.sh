#!/bin/bash

# ============================================================
#  web_prep.sh — Ianseo preparation and startup script
# ============================================================

set -e

# ------------------------------------------------------------
#  notify_error — single error reporting hook
#    Logs to stderr. Extend here (webhook, email, file...) if
#    you want centralised notification: every error in the
#    script goes through this function.
# ------------------------------------------------------------
notify_error()
{
    local context="$1"
    local detail="$2"
    echo "[ERROR] ${context}: ${detail}" >&2
    # Hook for future: email, Slack/Discord webhook, healthcheck file...
    # curl -sf -X POST "$WEBHOOK_URL" -d "{\"text\":\"Ianseo web_prep: ${context} — ${detail}\"}" || true
}

# ------------------------------------------------------------
#  Variables
# ------------------------------------------------------------
: "${IANSEO_VERSION:?IANSEO_VERSION must be set}"
: "${MYSQL_USER:?MYSQL_USER must be set}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD must be set}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set}"

IANSEO_ZIP="/tmp/Ianseo_${IANSEO_VERSION}.zip"
INSTALL_DIR="/var/www/html/ianseo"
INDEX_PHP="$INSTALL_DIR/Install/index.php"
CONFIG_FILE="$INSTALL_DIR/Common/config.inc.php"
DB_HOST="${DB_HOST:-ianseo-install-db-1}"
IANSEO_URL="${IANSEO_URL:-http://localhost/ianseo/Update/index-action.php}"
IANSEO_UPDATE_USER="${IANSEO_UPDATE_USER:-}"
IANSEO_UPDATE_PASS="${IANSEO_UPDATE_PASS:-}"

# ------------------------------------------------------------
#  directory_prep
# ------------------------------------------------------------
directory_prep()
{
    echo "==> Preparing installation directory..."
    if ! mkdir -p "$INSTALL_DIR"; then
        notify_error "directory_prep" "cannot create ${INSTALL_DIR}"
        exit 1
    fi
}

# ------------------------------------------------------------
#  download_ianseo — download only if not already installed
# ------------------------------------------------------------
download_ianseo()
{
    if [ -f "$INSTALL_DIR/index.php" ]; then
        echo "[OK] Ianseo already installed, skipping download."
        return 0
    fi

    if [ -f "$IANSEO_ZIP" ] && [ -s "$IANSEO_ZIP" ]; then
        echo "[OK] Archive already downloaded."
        return 0
    fi

    echo "==> Downloading Ianseo version ${IANSEO_VERSION}..."
    if ! curl -fL "https://ianseo.net/Release/Ianseo_${IANSEO_VERSION}.zip" -o "$IANSEO_ZIP"; then
        notify_error "download_ianseo" "failed to download Ianseo_${IANSEO_VERSION}.zip"
        exit 1
    fi
    if [ ! -s "$IANSEO_ZIP" ]; then
        notify_error "download_ianseo" "downloaded file is empty or corrupted"
        exit 1
    fi
    echo "[OK] Download completed."
}

# ------------------------------------------------------------
#  extract_ianseo_zip
# ------------------------------------------------------------
extract_ianseo_zip()
{
    if [ ! -f "$INSTALL_DIR/index.php" ]; then
        echo "==> Extracting ${IANSEO_ZIP}..."
        if ! unzip -q "$IANSEO_ZIP" -d "$INSTALL_DIR"; then
            notify_error "extract_ianseo_zip" "unzip failed for ${IANSEO_ZIP}"
            exit 1
        fi
        rm -f "$IANSEO_ZIP"
        echo "[OK] Extraction completed."
    fi
}

# ------------------------------------------------------------
#  ianseo_tweaks
#    1. Set the database host in Install/index.php
#    2. Fix a known typo in UpdateDb.inc.php (MD5-guarded)
# ------------------------------------------------------------
ianseo_tweaks()
{
    echo "==> Modifying ${INDEX_PHP}..."
    if [ ! -f "$INDEX_PHP" ]; then
        notify_error "ianseo_tweaks" "file ${INDEX_PHP} not found"
        exit 1
    fi
    if ! sed -i "s/W_HOST='localhost'/W_HOST='${DB_HOST}'/" "$INDEX_PHP"; then
        notify_error "ianseo_tweaks" "could not set the database host in index.php"
        exit 1
    fi
    echo "[OK] index.php updated."

    local update_db_file="$INSTALL_DIR/Common/UpdateDb.inc.php"
    if [ -f "$update_db_file" ]; then
        local md5
        md5=$(md5sum "$update_db_file" | awk '{ print $1 }')
        if [ "$md5" = "9b97ce0acf64cdd6df6dadfd5e72bead" ]; then
            echo "==> Applying patch to UpdateDb.inc.php..."
            if ! sed -i 's/if($u=safe_fetch($q))/if($u=safe_fetch($t))/' "$update_db_file"; then
                notify_error "ianseo_tweaks" "failed to apply the UpdateDb.inc.php patch"
                exit 1
            fi
            echo "[OK] Patch applied."
        fi
    fi
}

# ------------------------------------------------------------
#  set_permissions
# ------------------------------------------------------------
set_permissions()
{
    echo "==> Adjusting ownership and permissions..."
    if ! chown -R www-data:www-data "$INSTALL_DIR"; then
        notify_error "set_permissions" "chown failed on ${INSTALL_DIR}"
        exit 1
    fi
    if ! chmod -R u+wX "$INSTALL_DIR"; then
        notify_error "set_permissions" "chmod failed on ${INSTALL_DIR}"
        exit 1
    fi
    echo "[OK] Permissions adjusted."
}

# ------------------------------------------------------------
#  update_ianseo — wait for DB, import initial schema if empty
# ------------------------------------------------------------
update_ianseo()
{
    echo "==> Checking Ianseo database..."

    local db_ready=0 i
    for i in $(seq 1 30); do
        if mysqladmin ping -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl > /dev/null 2>&1; then
            db_ready=1
            break
        fi
        echo "    Waiting for database... (${i}/30)"
        sleep 1
    done
    if [ "$db_ready" -ne 1 ]; then
        notify_error "update_ianseo" "database server ${DB_HOST} is not reachable"
        exit 1
    fi

    local table_exists
    table_exists=$(mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl \
        "${MYSQL_DATABASE}" -N -e "SHOW TABLES LIKE 'Parameters';" 2>/dev/null | wc -l) || table_exists=0

    if [ "${table_exists:-0}" -eq 0 ]; then
        echo "==> Database is empty, importing initial SQL schema..."
        if [ ! -f "$INSTALL_DIR/Install/install.sql" ]; then
            notify_error "update_ianseo" "install.sql not found in $INSTALL_DIR/Install/"
            exit 1
        fi
        if ! mysql -h "${DB_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --skip-ssl "${MYSQL_DATABASE}" \
            < "$INSTALL_DIR/Install/install.sql"; then
            notify_error "update_ianseo" "failed to import install.sql into the database"
            exit 1
        fi
        echo "[OK] Database installed successfully."
    else
        echo "[OK] Database already initialized — nothing to do."
    fi
}

# ------------------------------------------------------------
#  generate_config — root config.php + Common/config.inc.php
# ------------------------------------------------------------
generate_config()
{
    local root_config="$INSTALL_DIR/config.php"
    if [ ! -f "$root_config" ]; then
        echo "==> Creating root configuration file config.php..."
        if ! cat << EOF > "$root_config"
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
        then
            notify_error "generate_config" "failed to write ${root_config}"
            exit 1
        fi
        if ! chown www-data:www-data "$root_config"; then
            notify_error "generate_config" "chown failed on ${root_config}"
            exit 1
        fi
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "==> Creating Common/config.inc.php..."
        if ! mkdir -p "$(dirname "$CONFIG_FILE")"; then
            notify_error "generate_config" "cannot create $(dirname "$CONFIG_FILE")"
            exit 1
        fi
        if ! cat << EOF > "$CONFIG_FILE"
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
        then
            notify_error "generate_config" "failed to write ${CONFIG_FILE}"
            exit 1
        fi
        if ! chown www-data:www-data "$CONFIG_FILE"; then
            notify_error "generate_config" "chown failed on ${CONFIG_FILE}"
            exit 1
        fi
    fi

    echo "[OK] Configuration files created."
}

# ------------------------------------------------------------
#  showProcess — poll getInfo until finished
# ------------------------------------------------------------
showProcess()
{
    local resp error status finished msg poll=0

    while true; do
        resp=$(curl -sf -X POST "$IANSEO_URL" -d "act=getInfo" 2>&1) || {
            notify_error "Network (getInfo)" "curl failed at poll ${poll}: ${resp:-no output}"
            return 1
        }

        error=$(echo "$resp" | jq -r '.error // 1' 2>/dev/null) || error=""
        if [ -z "$error" ]; then
            notify_error "Response (getInfo)" "invalid JSON at poll ${poll}: ${resp:0:200}"
            return 1
        fi
        if [ "$error" != "0" ]; then
            notify_error "Update (getInfo)" "$(echo "$resp" | jq -r '.msg // "no message provided"')"
            return 1
        fi

        status=$(echo "$resp" | jq -r '.status // ""' | sed -e 's/<[^>]*>//g' | tail -n 1)
        finished=$(echo "$resp" | jq -r '.finished // 0')

        poll=$((poll + 1))
        if [ "$poll" -gt 900 ]; then
            notify_error "Update (timeout)" "still not finished after 900 polls (~15 min)"
            return 1
        fi

        if [ "$finished" != "0" ]; then
            msg=$(echo "$resp" | jq -r '.msg // ""')
            if [ -n "$msg" ]; then
                notify_error "Update (final status)" "$(echo "$msg" | sed -e 's/<[^>]*>//g')"
                return 1
            fi
            echo "[OK] Progress: ${status}"
            return 0
        fi

        echo "    ${status}"
        sleep 1
    done
}

# ------------------------------------------------------------
#  doUpdate — getFile → doUpdate → poll progress
# ------------------------------------------------------------
doUpdate()
{
    local force="${1:-0}"
    local resp error msg

    echo "==> Starting Ianseo update..."

    command -v curl > /dev/null 2>&1 || { notify_error "Environment" "curl is not installed"; return 1; }
    command -v jq   > /dev/null 2>&1 || { notify_error "Environment" "jq is not installed"; return 1; }

    # 1. Prepare the update (creates updating.json)
    resp=$(curl -sf -X POST "$IANSEO_URL" -d "act=getFile&force=${force}" 2>&1) || {
        notify_error "Network (getFile)" "${resp:-no output}"
        return 1
    }
    error=$(echo "$resp" | jq -r '.error // 1' 2>/dev/null) || error=""
    if [ -z "$error" ]; then
        notify_error "Response (getFile)" "invalid JSON: ${resp:0:200}"
        return 1
    fi
    if [ "$error" != "0" ]; then
        msg=$(echo "$resp" | jq -r '.msg // "no message provided"')
        notify_error "Update (getFile)" "${msg}"
        return 1
    fi

    # 2. Launch the official updater (may take minutes — rely on the poll below)
    curl -s -X POST "$IANSEO_URL" \
        -d "act=doUpdate&user=${IANSEO_UPDATE_USER}&pwd=${IANSEO_UPDATE_PASS}" \
        > /dev/null 2>&1 || true

    # 3. Follow progress
    if ! showProcess; then
        notify_error "doUpdate" "progress monitoring failed — update status unknown"
        return 1
    fi

    echo "[OK] Update completed without errors."
    return 0
}

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

# Enable Apache configuration
a2enconf ianseo > /dev/null 2>&1 || true

# Debug phpinfo (only if provided in /tmp)
if [ -f /tmp/phpinfo.php ]; then
    echo "==> Enabling phpinfo.php debug file..."
    if ! cp /tmp/phpinfo.php /var/www/html/phpinfo.php; then
        notify_error "Main (phpinfo)" "failed to copy /tmp/phpinfo.php"
    elif ! chown www-data:www-data /var/www/html/phpinfo.php; then
        notify_error "Main (phpinfo)" "chown failed on /var/www/html/phpinfo.php"
    else
        echo "[OK] phpinfo.php enabled."
    fi
fi

echo "[OK] web_prep script completed."
echo "==> Starting application..."

# Start Apache in the background so the update can reach it via HTTP
apache2-foreground &
APACHE_PID=$!

# Wait until the web server answers (max ~30s)
# NOTE: probe /ianseo/ — the DocumentRoot itself has no index file
# and answers 403, which would make curl -sf fail forever.
i=0
until curl -sf -o /dev/null "http://localhost/ianseo/"; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        notify_error "Main (startup)" "web server did not come up after 30s"
        kill "$APACHE_PID" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Run the update; do NOT kill the container if it fails
if ! doUpdate "${IANSEO_UPDATE_FORCE:-0}"; then
    notify_error "Main (update)" "Ianseo update failed — container continues anyway"
fi

# Apache stays in the foreground (keeps the container alive)
wait "$APACHE_PID"