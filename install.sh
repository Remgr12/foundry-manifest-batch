#!/bin/bash

# --- Configuration ---
# File to read URLs from when using the -f flag
url_file="links.txt"
# Temporary file for JSON
temp_json="temp_module_manifest.json"

# --- Check prerequisites ---
command -v wget >/dev/null 2>&1 || { echo >&2 "Error: wget is required but it's not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "Error: jq is required but it's not installed. Aborting."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "Error: unzip is required but it's not installed. Aborting."; exit 1; }

# --- Argument Parsing & URL Source Determination ---
urls_to_process=() # Array to hold the final list of URLs
use_file=false

if [ "$#" -gt 0 ]; then
    if [ "$1" == "-f" ]; then
        use_file=true
        if [ "$#" -gt 1 ]; then
            echo "Warning: Additional arguments are ignored when using the -f flag."
        fi
    else
        # Treat all arguments as URLs if the first one isn't -f
        urls_to_process=("$@")
        echo "Reading URLs from command-line arguments."
    fi
else
    # No arguments provided at all
    echo "Usage: $0 [-f] | <manifest_url1> [manifest_url2] ..."
    echo ""
    echo "Options:"
    echo "  <url>...       Provide one or more manifest URLs directly."
    echo "  -f             Read manifest URLs from the file '$url_file' (one URL per line)."
    echo ""
    echo "Error: No manifest URLs provided and -f option not used."
    exit 1
fi

# If using file, try to read it
if [ "$use_file" = true ]; then
    if [ -f "$url_file" ] && [ -r "$url_file" ]; then
        echo "Reading URLs from file: $url_file"
        # Read file line by line into the array, skipping empty lines and comments starting with #
        mapfile -t urls_to_process < <(grep -vE '^\s*(#|$)' "$url_file")
        if [ ${#urls_to_process[@]} -eq 0 ]; then
             echo "Error: '$url_file' exists but contains no valid URLs (or only comments/empty lines)."
             exit 1
        fi
        echo "Found ${#urls_to_process[@]} URL(s) in $url_file."
    else
        echo "Error: Cannot read URLs from '$url_file'. File does not exist or is not readable."
        exit 1
    fi
fi

# --- Sanity check if we have URLs ---
if [ ${#urls_to_process[@]} -eq 0 ]; then
     echo "Error: No URLs to process found from either command line or file."
     exit 1
fi

# --- Main loop ---
num_urls=${#urls_to_process[@]}
echo "Starting module download and extraction process for $num_urls URL(s)..."

# Iterate over the collected URLs
for json_url in "${urls_to_process[@]}"; do
    # --- (The rest of the processing loop remains the same as before) ---
    echo "----------------------------------------"
    echo "Processing manifest URL: $json_url"

    # 1. Download the module.json file
    wget --timeout=15 --tries=2 -q -O "$temp_json" "$json_url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download manifest from $json_url. Skipping."
        continue
    fi
    echo "Manifest downloaded."

    # 2. Extract download URL and module ID (use 'id' or fallback to 'name')
    download_url=$(jq -r '.download' "$temp_json")
    module_id=$(jq -r '.id // .name' "$temp_json") # Use .id, fallback to .name if id is null/missing

    # Check if extraction was successful
    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        echo "Error: Could not extract 'download' URL from manifest ($json_url). Skipping."
        rm -f "$temp_json" # Clean up temp file
        continue
    fi
     if [ -z "$module_id" ] || [ "$module_id" == "null" ]; then
        echo "Warning: Could not extract module 'id' or 'name' from manifest ($json_url). Using generic folder name."
        timestamp=$(date +%s%N) # High precision timestamp for uniqueness
        module_id="unknown_module_${timestamp}"
    fi

    echo "Module ID/Name: $module_id"
    echo "Download URL: $download_url"

    # Define zip filename
    zip_filename="${module_id}.zip"

    # 3. Download the actual module ZIP file
    echo "Downloading module package..."
    wget --timeout=30 --tries=2 -q -O "$zip_filename" "$download_url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download module package from $download_url. Skipping."
        rm -f "$temp_json" # Clean up manifest
        continue
    fi
    echo "Module package downloaded: $zip_filename"

    # 4. Create the destination folder
    echo "Creating directory: $module_id"
    mkdir -p "$module_id"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create directory '$module_id'. Skipping unzip."
        rm -f "$temp_json" "$zip_filename" # Clean up
        continue
    fi

    # 5. Unzip the package into the folder
    echo "Unzipping $zip_filename into $module_id/"
    unzip -q "$zip_filename" -d "$module_id"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to unzip '$zip_filename' into '$module_id'. Manual check required (zip kept)."
    else
        echo "Successfully extracted."
        # 6. Clean up the downloaded zip file on success
        rm -f "$zip_filename"
    fi

    # Clean up the temporary JSON file
    rm -f "$temp_json"
    # --- (End of the processing loop) ---
done

echo "----------------------------------------"
echo "Processing complete."
