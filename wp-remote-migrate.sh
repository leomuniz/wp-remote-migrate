#!/bin/bash
# -----------------------------------------------------------------------------
# wp-remote-migrate.sh
# -----------------------------------------------------------------------------
# A lightweight Bash script for seamlessly migrating remote WordPress sites
# to your local environment using rsync and WP-CLI.
#
# Version: 1.0.0
# Author: Leo Muniz - https://leomuniz.dev
# License: MIT (See LICENSE file for full details)
# -----------------------------------------------------------------------------

# ==========================
# WordPress Remote Migrate
# ==========================

CURRENT_VERSION=$(rsync --version | head -n 1 | awk '{print $3}')
REQUIRED_VERSION="3.1.0"

if [ "$(printf '%s\n%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$CURRENT_VERSION" ] && \
   [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
    echo "❌ Your rsync ($CURRENT_VERSION) is too old. This script requires a version higher than $REQUIRED_VERSION. Please update rsync."
    echo "   For macOS, try: brew install rsync"
    exit 1
fi

# Confirming Local WordPress Path
LOCAL_WP_PATH=$(pwd)

while [ ! -f "$LOCAL_WP_PATH/wp-config.php" ]; do
    LOCAL_WP_PATH=$(dirname "$LOCAL_WP_PATH")
    if [ "$LOCAL_WP_PATH" = "/" ]; then
        echo "❌ This doesn't seem a valid WP install! Please run this script from within a WordPress site."
        exit 1
    fi
done

CONFIG_FILE="$LOCAL_WP_PATH/.remote_wp_credentials"

if [ -f "$CONFIG_FILE" ]; then
    echo "Remote WP site credentials found at $CONFIG_FILE"

    source "$CONFIG_FILE"

    echo ""
    echo "🔍 Verifying inputs from config file..."
    echo "Remote Host: $REMOTE_HOST"
    echo "Remote Port: $REMOTE_PORT"
    echo "Remote User: $REMOTE_USER"
    echo "Remote Path: $REMOTE_PATH"
    echo "Local WP Path: $LOCAL_WP_PATH"
    echo "Local Site URL: $LOCAL_SITE_URL"
else
    # Ask for Remote Host
    read -p "🌐 Enter Remote Host (e.g., 123.123.123.123): " REMOTE_HOST
    if [[ -z "$REMOTE_HOST" ]]; then
        echo "❌ Remote Host is required!"
        exit 1
    fi

    # Ask for Remote Port (with a default value)
    read -r -p "📂 Enter Remote Port [default: 22]: " REMOTE_PORT_INPUT
    REMOTE_PORT=${REMOTE_PORT_INPUT:-22}  # Set default if empty

    # Ask for Remote User
    read -p "👤 Enter Remote User (e.g., user): " REMOTE_USER
    if [[ -z "$REMOTE_USER" ]]; then
        echo "❌ Remote User is required!"
        exit 1
    fi

    # Ask for Remote Path (with a default value)
    read -p "📂 Enter Remote Path [default: ~/public]: " REMOTE_PATH
    REMOTE_PATH=${REMOTE_PATH:-'~/public'}  # Set default if empty

    # Ask for Local Site URL
    read -p "🔗 Enter Local Site URL (including http/https protocol e.g., https://mysite.local): " LOCAL_SITE_URL
    if [[ -z "$LOCAL_SITE_URL" ]]; then
        echo "❌ Local Site URL is required!"
        exit 1
    fi

    # Save credentials to config file
    echo "REMOTE_HOST=\"$REMOTE_HOST\"" > "$CONFIG_FILE"
    echo "REMOTE_PORT=\"$REMOTE_PORT\"" >> "$CONFIG_FILE"
    echo "REMOTE_USER=\"$REMOTE_USER\"" >> "$CONFIG_FILE"
    echo "REMOTE_PATH=\"$REMOTE_PATH\"" >> "$CONFIG_FILE"
    echo "LOCAL_SITE_URL=\"$LOCAL_SITE_URL\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

# Determine the directory of the script and load defaults if available
SCRIPT_DIR="$(dirname "$0")"
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/wp-remote-migrate-default.sh"

if [ -f "$DEFAULT_CONFIG_FILE" ]; then
    source "$DEFAULT_CONFIG_FILE"
fi

# Ask if WP version should be checked

while true; do
    echo ""
    read -p "🔄 Should the WP version be checked and matched? (y/n): " CHECK_WP_VERSION
    CHECK_WP_VERSION=$(echo "$CHECK_WP_VERSION" | tr '[:upper:]' '[:lower:]')

    # Convert single letters
    if [[ "$CHECK_WP_VERSION" == "y" ]]; then
        CHECK_WP_VERSION="yes"
    elif [[ "$CHECK_WP_VERSION" == "n" ]]; then
        CHECK_WP_VERSION="no"
    fi

    if [[ "$CHECK_WP_VERSION" == "yes" || "$CHECK_WP_VERSION" == "no" ]]; then
        break  # Valid input, exit the loop
    else
        echo "❌ Invalid input. Please type 'yes' or 'no'."
    fi
done

# Ask how plugins should be synchronized
while true; do
    echo ""
    echo "🔌 Plugins: How should they be synchronized?"
    echo "  1. Skip plugins"
    echo "  2. Download ALL plugins"
    echo "  3. Download ONLY enabled plugins"
    read -p "Enter your choice (1/2/3): " PLUGIN_CHOICE

    if [[ "$PLUGIN_CHOICE" != "1" && "$PLUGIN_CHOICE" != "2" && "$PLUGIN_CHOICE" != "3" ]]; then
        echo "❌ Invalid choice. Please select 1, 2, or 3."
    else
        break  # Valid input, exit the loop
    fi
done

while true; do
    echo ""
    echo "🎨 Themes: How should they be synchronized?"
    echo "  1. Skip themes"
    echo "  2. Download ALL themes"
    echo "  3. Download ONLY enabled theme(s)"
    read -p "Enter your choice (1/2/3): " THEME_CHOICE

    if [[ "$THEME_CHOICE" != "1" && "$THEME_CHOICE" != "2" && "$THEME_CHOICE" != "3" ]]; then
        echo "❌ Invalid choice. Please select 1, 2, or 3."
    else
        break  # Valid input, exit the loop
    fi
done

# Ask how uploads should be synced
while true; do
    echo ""
    echo "📂 How should the uploads folder be handled?"
    echo "  1. Skip uploads"
    echo "  2. Sync uploads (update changed and download missing files)"
    echo "  3. Sync uploads and delete local files not present on the remote"
    read -p "Enter your choice (1/2/3): " UPLOADS_CHOICE

    if [[ "$UPLOADS_CHOICE" != "1" && "$UPLOADS_CHOICE" != "2" && "$UPLOADS_CHOICE" != "3" ]]; then
        echo "❌ Invalid choice. Please select 1, 2, or 3."
    else
        break  # Valid input, exit the loop
    fi
done

if [[ "$UPLOADS_CHOICE" == "2" || "$UPLOADS_CHOICE" == "3" ]]; then

    # Prompt for max file size
    if [ -n "$DEFAULT_MAX_SIZE" ]; then
        read -p "🚦 Enter max file size to download from uploads (e.g. '50m', leave blank for default [$DEFAULT_MAX_SIZE]): " MAX_SIZE_INPUT
    else
        read -p "🚦 Enter max file size to download from uploads (e.g. '50m', leave blank to download files of any size): " MAX_SIZE_INPUT
    fi
    MAX_SIZE=${MAX_SIZE_INPUT:-$DEFAULT_MAX_SIZE}

    # Prompt for file extensions to exclude
    if [ -n "$DEFAULT_EXCLUDED_EXTENSIONS" ]; then
        read -p "❌ Enter file extensions to exclude from uploads (space-separated, e.g. 'mp4 avi pdf', leave blank for default [$DEFAULT_EXCLUDED_EXTENSIONS]): " EXCLUDED_EXTENSIONS_INPUT
    else
        read -p "❌ Enter file extensions to exclude from uploads (space-separated, e.g. 'mp4 avi pdf', leave blank if none): " EXCLUDED_EXTENSIONS_INPUT
    fi
    EXCLUDED_EXTENSIONS=${EXCLUDED_EXTENSIONS_INPUT:-$DEFAULT_EXCLUDED_EXTENSIONS}
fi

# Ask if database should be downloaded
while true; do
    echo ""
    read -p "🗄️ Should the database be downloaded and overwrite the local database? (y/n): " DOWNLOAD_DB
    DOWNLOAD_DB=$(echo "$DOWNLOAD_DB" | tr '[:upper:]' '[:lower:]')

    # Convert single letters
    if [[ "$DOWNLOAD_DB" == "y" ]]; then
        DOWNLOAD_DB="yes"
    elif [[ "$DOWNLOAD_DB" == "n" ]]; then
        DOWNLOAD_DB="no"
    fi

    if [[ "$DOWNLOAD_DB" == "yes" || "$DOWNLOAD_DB" == "no" ]]; then
        break  # Valid input, exit the loop
    else
        echo "❌ Invalid input. Please type 'yes' or 'no'."
    fi
done

# Prompt for tables to exclude
if [[ "$DOWNLOAD_DB" == "yes" ]]; then
    if [ -n "$DEFAULT_TABLES_TO_EXCLUDE" ]; then
        read -p "🔍 Enter the tables to exclude (comma-separated, e.g., 'wp_comments,wp_commentmeta', leave blank for default [$DEFAULT_TABLES_TO_EXCLUDE]): " TABLES_TO_EXCLUDE_INPUT
    else
        read -p "🔍 Enter the tables to exclude (comma-separated, e.g., 'wp_comments,wp_commentmeta', leave blank if none): " TABLES_TO_EXCLUDE_INPUT
    fi
    TABLES_TO_EXCLUDE=${TABLES_TO_EXCLUDE_INPUT:-$DEFAULT_TABLES_TO_EXCLUDE}
fi

# Confirm Inputs
echo ""
echo "🔍 Verifying inputs:"
echo "Remote Host: $REMOTE_HOST"
echo "Remote Port: $REMOTE_PORT"
echo "Remote User: $REMOTE_USER"
echo "Remote Path: $REMOTE_PATH"
echo "Local WP Path: $LOCAL_WP_PATH"
echo "Local Site URL: $LOCAL_SITE_URL"

echo ""
echo "🔍 Verifying additional settings:"
echo "Match WP Version: $CHECK_WP_VERSION"
echo "Plugins Handling: $( [[ "$PLUGIN_CHOICE" == "1" ]] && echo 'Skip plugins' || ([[ "$PLUGIN_CHOICE" == "2" ]] && echo 'Download ALL plugins' || echo 'Download ONLY enabled plugins'))"
echo "Themes Handling: $( [[ "$THEME_CHOICE" == "1" ]] && echo 'Skip themes' || ([[ "$THEME_CHOICE" == "2" ]] && echo 'Download ALL themes' || echo 'Download ONLY enabled theme(s)'))"
echo "Uploads Handling: $( [[ "$UPLOADS_CHOICE" == "1" ]] && echo 'Skip uploads' || ([[ "$UPLOADS_CHOICE" == "2" ]] && echo 'Sync uploads (update changed and download missing files)' || echo 'Sync uploads and delete local files not present on the remote'))"

if [[ "$UPLOADS_CHOICE" != "1" ]]; then
    if [[ -z "$MAX_SIZE" ]]; then
        echo "  Max File Size: no limit"
    else
        echo "  Max File Size: $MAX_SIZE"
    fi

    if [[ -z "$EXCLUDED_EXTENSIONS" ]]; then
        echo "  Excluded Extensions: None. Download all files."
    else
        echo "  Excluded Extensions: $EXCLUDED_EXTENSIONS"
    fi
fi

echo "Overwrite Database: $DOWNLOAD_DB"

if [[ "$TABLES_TO_EXCLUDE" ]]; then
    echo "Tables to Exclude: $TABLES_TO_EXCLUDE"
fi

echo ""
read -p "✅ Are these correct? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "❌ Aborting script. Please re-run and provide correct values."
    exit 1
fi

# 🛡️ Validation: Check if LOCAL_PATH exists
echo ""
if [ ! -d "$LOCAL_WP_PATH" ]; then
    echo "❌ Error: Local path $LOCAL_WP_PATH does not exist. Please set up the WP local host first."
    exit 1
fi

LOCAL_WP_PATH=$(cd "$LOCAL_WP_PATH" && pwd)
LOCAL_WP_CLI="wp --path=$LOCAL_WP_PATH"

if ! wp core is-installed --path="$LOCAL_WP_PATH" >/dev/null 2>&1; then
    echo "❌ WordPress is NOT installed in $LOCAL_WP_PATH or could not run WP CLI."
    exit 1
fi

# 🛡️ Validation: Check connectivity to remote host
echo ""
echo "🔑 Checking SSH connectivity to $REMOTE_USER@$REMOTE_HOST on port $REMOTE_PORT..."
ssh -p "$REMOTE_PORT" -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" "exit" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "❌ Could not connect to $REMOTE_USER@$REMOTE_HOST on port $REMOTE_PORT."
  exit 1
fi

echo "✅ SSH connectivity verified. Proceeding with further commands..."

echo ""
echo "🚀 Starting the WordPress site pull process..."
echo ""

# ========================
# 1️⃣ Access Remote Host and Check WP Version
# ========================
if [[ "$CHECK_WP_VERSION" == "yes" ]]; then
    echo "🔄 Checking WordPress version..."
    REMOTE_WP_VERSION=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp core version")
    echo "🌐 Remote WordPress version: $REMOTE_WP_VERSION"

    LOCAL_WP_VERSION=$($LOCAL_WP_CLI core version)
    echo "💻 Local WordPress version: $LOCAL_WP_VERSION"

    if [[ "$REMOTE_WP_VERSION" != "$LOCAL_WP_VERSION" ]]; then
        echo "⚠️ WordPress versions differ (Remote: $REMOTE_WP_VERSION, Local: $LOCAL_WP_VERSION). Updating local WordPress version..."
        $LOCAL_WP_CLI core update --version="$REMOTE_WP_VERSION" --force
    else
        echo "✅ WordPress versions match."
    fi
fi

# ========================
# 2️⃣ Sync Plugins
# ========================
echo ""

if [[ "$PLUGIN_CHOICE" == "1" ]]; then
    echo "❌ Skipping plugins synchronization."

elif [[ "$PLUGIN_CHOICE" == "2" ]]; then
    echo "🔌 Downloading ALL plugins..."
    mkdir -p "$LOCAL_WP_PATH/wp-content/plugins/"
    rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
      "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/plugins/" \
      "$LOCAL_WP_PATH/wp-content/plugins/"
    echo "✅ All plugins synced."

elif [[ "$PLUGIN_CHOICE" == "3" ]]; then
    echo "🔌 Downloading ONLY enabled plugins..."

    # 1) Get active plugin folders from remote
    #    This returns a list of plugin 'names' (actually folder or plugin file base names)
    ACTIVE_PLUGINS=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp plugin list --status=active --field=name")

    # 2) For each active plugin, rsync only that folder
    #    Assuming each plugin is in its own subfolder that matches the 'name'
    for plugin in $ACTIVE_PLUGINS; do
        echo ""
        echo "Syncing plugin: $plugin"
        mkdir -p "$LOCAL_WP_PATH/wp-content/plugins/$plugin"
        rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
          "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/plugins/$plugin/" \
          "$LOCAL_WP_PATH/wp-content/plugins/$plugin/"
    done

    echo ""
    echo "✅ Active plugins synced."
fi

# ========================
# 3️⃣ Sync Must-use Plugins
# ========================
if [[ "$PLUGIN_CHOICE" != "1" ]]; then
    echo ""
    echo "📂 Syncing mu-plugins..."
    rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/mu-plugins/" \
    "$LOCAL_WP_PATH/wp-content/mu-plugins/"

    echo "✅ mu-plugins synchronized."
fi

# ========================
# 4️⃣ Sync Themes
# ========================
echo ""

if [[ "$THEME_CHOICE" == "1" ]]; then
    echo "❌ Skipping themes synchronization."

elif [[ "$THEME_CHOICE" == "2" ]]; then
    echo "🎨 Downloading ALL themes..."
    rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
      "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/themes/" \
      "$LOCAL_WP_PATH/wp-content/themes/"
    echo "✅ All themes synced."

elif [[ "$THEME_CHOICE" == "3" ]]; then
    echo "🎨 Downloading ONLY enabled theme(s)..."


    # 1) Get active theme(s) names
    ACTIVE_THEMES=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "cd $REMOTE_PATH && wp theme list --status=active --field=name")

    for theme in $ACTIVE_THEMES; do
        echo ""
        echo "Syncing active theme: $theme"

        # rsync the active (child) theme
        rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/themes/$theme/" \
            "$LOCAL_WP_PATH/wp-content/themes/$theme/"

        # 2) Detect if this theme is a child. If so, get its parent.
        PARENT_THEME=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" \
            "cd $REMOTE_PATH && wp theme get $theme --field=template" 2>/dev/null)

        # If the parent is different from the child, then sync it.
        if [[ -n "$PARENT_THEME" && "$PARENT_THEME" != "$theme" ]]; then
            echo ""
            echo "Detected parent theme: $PARENT_THEME"
            rsync -azh --info=progress2 -e "ssh -p $REMOTE_PORT" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/themes/$PARENT_THEME/" \
            "$LOCAL_WP_PATH/wp-content/themes/$PARENT_THEME/"
        fi
    done

    echo "✅ Active theme(s) synced."
fi

# ========================
# 5️⃣ Sync Uploads
# ========================
echo ""

if [[ "$UPLOADS_CHOICE" == "1" ]]; then
    echo "❌ Skipping uploads synchronization."

else

    RSYNC_FLAGS="-azh --info=progress2"   # base flags
    if [[ "$UPLOADS_CHOICE" == "2" ]]; then
        RSYNC_FLAGS+=" --ignore-existing"
    elif [[ "$UPLOADS_CHOICE" == "3" ]]; then
        RSYNC_FLAGS+=" --delete"
    fi

    if [[ -n "$MAX_SIZE" ]]; then
      RSYNC_FLAGS+=" --max-size=$MAX_SIZE"
    fi

    if [[ -n "$EXCLUDED_EXTENSIONS" ]]; then
      for ext in $EXCLUDED_EXTENSIONS; do
        RSYNC_FLAGS+=" --exclude=\"*.$ext\""
      done
    fi

    REMOTE_YEARS=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "cd $REMOTE_PATH && cd \"wp-content/uploads\" && ls -d 20*/ 2>/dev/null | cut -f1 -d'/'")

    # ---- B. Prompt user for which years to download ----
    echo ""
    echo "📂 Available remote upload years:"
    echo "$REMOTE_YEARS"
    echo ""
    read -p "🔎 Enter the years you want to download (space-separated). Leave blank to download ALL: " SELECTED_YEARS

    # Sync selected years.
    for year in $SELECTED_YEARS; do
        # Verify the year actually exists on remote
        if echo "$REMOTE_YEARS" | grep -wq "$year"; then
            echo ""
            echo "📂 Downloading uploads for year: $year"

            # Start building the command
            RSYNC_CMD="rsync $RSYNC_FLAGS -e \"ssh -p $REMOTE_PORT\""
            RSYNC_CMD+=" \"$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/uploads/$year/\""
            RSYNC_CMD+=" \"$LOCAL_WP_PATH/wp-content/uploads/$year/\""

            mkdir -p "$LOCAL_WP_PATH/wp-content/uploads/$year"

            echo "👉 Running: $RSYNC_CMD"
            eval "$RSYNC_CMD"

            echo "✅ Finished syncing year: $year"
        else
            echo ""
            echo "⚠️ Year '$year' doesn't exist on the remote. Skipping."
        fi
    done

    # Sync non-year folders.
    echo ""
    echo "📂 Downloading non-year uploads..."

    rsync $RSYNC_FLAGS \
    --exclude='20*' \
    -e "ssh -p $REMOTE_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/uploads/" \
    "$LOCAL_WP_PATH/wp-content/uploads/"

    echo "✅ Uploads synced."
fi


if [[ "$DOWNLOAD_DB" == "yes" ]]; then
    echo ""

    # =====================================
    # 4️⃣ Access Remote Host: Create DB dump
    # =====================================
    echo ""
    echo "📦 Creating database dump on remote server..."
    if [[ -n "$TABLES_TO_EXCLUDE" ]]; then
        SKIP_TABLES_PARAM="--exclude_tables=$TABLES_TO_EXCLUDE"
    else
        SKIP_TABLES_PARAM=""
    fi
    ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "
        cd $REMOTE_PATH &&
        wp db export db_backup.sql $SKIP_TABLES_PARAM
    "

    # ===========================
    # 5️⃣ Copy Files to Local Site
    # ===========================
    echo ""
    echo "⬇️ Copying files from remote to local site..."
    scp -P $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/db_backup.sql .

    echo ""
    echo "Removing unwanted data from the database dump..."
    sed -E '1s/^\xEF\xBB\xBF//; s/(\/\*![0-9]+)\\-/\1-/' db_backup.sql > temp.sql && mv temp.sql db_backup.sql
    echo "✅ Unwanted data removed."

    # ========================
    # 7️⃣ Import Database
    # ========================
    echo ""
    echo "🛢️ Importing database..."
    $LOCAL_WP_CLI db import db_backup.sql

    # Delete local database dump.
    # rm db_backup.sql

    # Delete remote database dump.
    ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "
        cd $REMOTE_PATH &&
        rm db_backup.sql
    "

    # ==============
    # 8️⃣ Update URLs
    # ==============
    echo ""
    echo "🔗 Running search-replace for URLs..."

    # Fetch Remote Site URL
    REMOTE_SITE_URL=$(wp option get siteurl)
    echo "🌍 Remote Site URL: $REMOTE_SITE_URL"

    REMOTE_BASE_DOMAIN="${REMOTE_SITE_URL#http://}"
    REMOTE_BASE_DOMAIN="${REMOTE_BASE_DOMAIN#https://}"
    REMOTE_BASE_DOMAIN="${REMOTE_BASE_DOMAIN%/}"

    # Replace Remote URL with Local URL
    $LOCAL_WP_CLI search-replace "http://$REMOTE_BASE_DOMAIN" "$LOCAL_SITE_URL" --all-tables
    $LOCAL_WP_CLI search-replace "https://$REMOTE_BASE_DOMAIN" "$LOCAL_SITE_URL" --all-tables

    # =====================
    # 9️⃣ Deactivate Plugins
    # =====================

    if [ -n "$DEFAULT_PLUGINS_TO_DEACTIVATE" ]; then
        echo ""
        echo "🔌 Deactivating specified plugins..."
        $LOCAL_WP_CLI plugin deactivate $DEFAULT_PLUGINS_TO_DEACTIVATE

        echo  ""
        echo "✅ Specified plugins have been deactivated."
    fi

else
    echo "❌ Skipping database download."
fi

echo ""
echo "🎉 WordPress site successfully pulled from $REMOTE_HOST."
echo "🌐 Access your site at: $LOCAL_SITE_URL"
