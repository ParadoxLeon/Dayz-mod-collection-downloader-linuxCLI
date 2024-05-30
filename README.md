# Dayz mod collection downloader
## How to Use the Script:

1. Create a workshop collection with all the mods you want and make sure it's public
2. Download jq ( apt install jq )
3. Save the script to a file, e.g., download_mods.sh
4. Edit the script to add you're collection id and to change settings
5. Make the script executable by running chmod +x download_mods.sh
6. Execute the script by running ./download_mods.sh and wait for it to finish

This script will handle downloading mods, renaming them, and extracting the keys while ensuring it only downloads mods if they have been updated since the last download. 

## IF the script seems stuck, wait a few minutes before canceling.
This can happen when the mod file is big.

Usually, the script will throw an error when something is wrong.

## Other games
This script should work with other games too, but you may need to make some adjustments.
