#!/bin/bash

# Configuration
STEAMCMD_PATH="youre_steamcmd_location/steamcmd.sh"    # Path where steamcmd is installed https://developer.valvesoftware.com/wiki/SteamCMD
STEAM_API_KEY="youre_steamapi_key"    # Steam API key get it here https://steamcommunity.com/dev/apikey
COLLECTION_ID="youre_collection_id"    # Workshop collection ID
MODS_DIR="youreserverfiles/mods"    # Directory where mods are downloaded
KEYS_DEST_DIR="youre_serverfiles/keys"    # Directory where to place the keys
GAME_ID="221100"                                        # Game ID for Dayz

VERSION_FILE="$MODS_DIR/mod_versions.txt"               # File to track mod versions

# Ensure keys destination directory exists
mkdir -p "$KEYS_DEST_DIR"

# Ensure mods directory exists
mods_workshop_dir="$MODS_DIR/steamapps/workshop/content/$GAME_ID"
mkdir -p "$mods_workshop_dir"

# Check if the version file exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "No version file found, treating it as a clean/first install."
    copy_all_mods=true
else
    copy_all_mods=false
fi

# Fetch collection details
collection_response=$(curl -s "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/" -d "key=${STEAM_API_KEY}&collectioncount=1&publishedfileids[0]=${COLLECTION_ID}")

# Check response
result=$(echo $collection_response | jq -r '.response.collectiondetails[0].result')
if [ "$result" != "1" ]; then
    echo "Error fetching collection details: $collection_response"
    exit 1
fi

# Extract mod IDs from the collection
mod_ids=$(echo $collection_response | jq -r '.response.collectiondetails[0].children[].publishedfileid')

# get the current version of a mod
get_current_version() {
    local mod_id=$1
    grep "^$mod_id " "$VERSION_FILE" | cut -d ' ' -f 2
}

update_version_file() {
    local mod_id=$1
    local new_version=$2
    sed -i "/^$mod_id /d" "$VERSION_FILE"
    echo "$mod_id $new_version" >> "$VERSION_FILE"
}

extract_keys() {
    local mod_path=$1
    local keys_path

    # Check for 'keys' and 'Keys' directories
    if [ -d "$mod_path/keys" ]; then
        keys_path="$mod_path/keys"
    elif [ -d "$mod_path/Keys" ]; then
        keys_path="$mod_path/Keys"
    else
        echo "No keys directory found in $mod_path"
        return
    fi

    # Copy contents of keys to KEYS_DEST_DIR
    echo "Copying keys from $keys_path to $KEYS_DEST_DIR"
    cp -r "$keys_path"/* "$KEYS_DEST_DIR"
}

# Log in and download all mods
{
    echo "force_install_dir $MODS_DIR"
    echo "login anonymous"
    for mod_id in $mod_ids; do
        # Get current version
        current_version=$(get_current_version $mod_id)

        mod_details=$(curl -s "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" -d "itemcount=1&publishedfileids[0]=$mod_id&key=${STEAM_API_KEY}")
        mod_name=$(echo $mod_details | jq -r '.response.publishedfiledetails[0].title')
        mod_updated=$(echo $mod_details | jq -r '.response.publishedfiledetails[0].time_updated')

        # Compare versions
        if [ "$mod_updated" != "$current_version" ] || [ "$copy_all_mods" = true ]; then
            echo "workshop_download_item $GAME_ID $mod_id validate"
            update_version_file $mod_id $mod_updated
        fi
    done
    echo "quit"
} | $STEAMCMD_PATH

# Loop through each mod ID
for mod_id in $mod_ids; do
    # Verify if download was successful
    mod_path="$mods_workshop_dir/$mod_id"
    if [ ! -d "$mod_path" ]; then
        echo "Failed to download or find mod ID: $mod_id at path: $mod_path"
        continue
    fi

    # Get mod details
    mod_details=$(curl -s "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" -d "itemcount=1&publishedfileids[0]=$mod_id&key=${STEAM_API_KEY}")
    mod_name=$(echo $mod_details | jq -r '.response.publishedfiledetails[0].title')
    mod_updated=$(echo $mod_details | jq -r '.response.publishedfiledetails[0].time_updated')

    current_version=$(get_current_version $mod_id)

    # Compare versions
    if [ "$mod_updated" != "$current_version" ] || [ "$copy_all_mods" = true ]; then
        mod_name_sanitized=$(echo $mod_name)
        new_mod_path="$MODS_DIR/@$mod_name_sanitized"

        echo "Copying mod folder from $mod_path to $new_mod_path"
        cp -r "$mod_path" "$new_mod_path"

        echo "Extracting keys for mod ID: $mod_id"
        extract_keys "$new_mod_path"

        # Update version file
        update_version_file $mod_id $mod_updated
    else
        echo "Skipping mod $mod_id as it is up to date."
    fi
done

echo "All mods checked, updated, renamed, and keys extracted."
