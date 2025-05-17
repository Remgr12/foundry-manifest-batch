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
command -v find >/dev/null 2>&1 || { echo >&2 "Error: find command is required. Aborting."; exit 1; }
command -v dirname >/dev/null 2>&1 || { echo >&2 "Error: dirname command is required. Aborting."; exit 1; }
command -v basename >/dev/null 2>&1 || { echo >&2 "Error: basename command is required. Aborting."; exit 1; }

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

if [ "$use_file" = true ]; then
    if [ -f "$url_file" ] && [ -r "$url_file" ]; then
        echo "Reading URLs from file: $url_file"
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

if [ ${#urls_to_process[@]} -eq 0 ]; then
     echo "Error: No URLs to process found from either command line or file."
     exit 1
fi
# --- End of argument parsing ---


echo "Starting module download and extraction process for ${#urls_to_process[@]} URL(s)..."

for json_url in "${urls_to_process[@]}"; do
    echo "----------------------------------------"
    echo "Processing manifest URL: $json_url"

    # 1. Download the module.json file
    wget --timeout=15 --tries=2 -q -O "$temp_json" "$json_url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download manifest from $json_url. Skipping."
        continue
    fi

    # 2. Extract download URL and module ID
    download_url=$(jq -r '.download // empty' "$temp_json")
    module_id=$(jq -r '.id // .name // empty' "$temp_json") # Use 'empty' for jq < 1.5 compatibility instead of "" for //

    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then # Also check for literal "null" string
        echo "Error: Could not extract 'download' URL from manifest ($json_url). Skipping."
        rm -f "$temp_json"
        continue
    fi
    if [ -z "$module_id" ] || [ "$module_id" == "null" ]; then
        echo "Warning: Could not extract module 'id' or 'name' from manifest ($json_url). Using generic folder name."
        timestamp=$(date +%s%N)
        module_id="unknown_module_${timestamp}"
    fi

    echo "Module ID: $module_id"
    echo "Download URL: $download_url"

    zip_filename="${module_id}.zip"
    target_module_dir="$module_id" # Final destination for module files (e.g., modules/module-id/)
    # Create a unique temporary extraction directory for each module
    temp_extract_dir="${module_id}_temp_extract_$$_$(date +%s%N)"

    # 3. Download the actual module ZIP file
    echo "Downloading module package..."
    wget --timeout=180 --tries=2 -q -O "$zip_filename" "$download_url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download module package for '$module_id' from $download_url. Skipping."
        rm -f "$temp_json"
        continue
    fi
    echo "Module package downloaded: $zip_filename"

    # 4. Create the final target module directory AND a temporary extraction directory
    # Ensure target_module_dir exists and is empty for a clean install
    if [ -d "$target_module_dir" ]; then
        echo "  Warning: Target directory '$target_module_dir' already exists. Clearing it for new installation."
        rm -rf "${target_module_dir:?}"/* # Protect against empty target_module_dir variable
        if [ $? -ne 0 ]; then
             # If rm fails, try to create a uniquely named target dir instead
             echo "  Error clearing '$target_module_dir'. Will try to install in a new uniquely named directory."
             target_module_dir="${module_id}_$(date +%s%N)"
        fi
    fi
    mkdir -p "$target_module_dir"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create target directory '$target_module_dir'. Skipping."
        rm -f "$temp_json" "$zip_filename"
        continue
    fi

    mkdir -p "$temp_extract_dir"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temporary extraction directory '$temp_extract_dir'. Skipping."
        rm -f "$temp_json" "$zip_filename"
        # rm -rf "$target_module_dir" # Optionally clean up target if temp fails and target was newly created
        continue
    fi

    # 5. Unzip the package into the temporary extraction directory
    echo "Unzipping $zip_filename into temporary directory $temp_extract_dir/"
    unzip -q -o "$zip_filename" -d "$temp_extract_dir"
    unzip_exit_code=$?

    if [ $unzip_exit_code -ne 0 ]; then
        echo "Error: Failed to unzip '$zip_filename' into '$temp_extract_dir'. Manual check required."
    else
        echo "Successfully unzipped to temporary directory."
        
        # Try to find the directory containing module.json within temp_extract_dir
        module_json_location=$(find "$temp_extract_dir" -name module.json -type f -print -quit)

        if [ -n "$module_json_location" ]; then
            source_content_parent_dir=$(dirname "$module_json_location")

            echo "  module.json found at: $module_json_location"
            echo "  Source content directory identified as: $source_content_parent_dir"

            # Move contents from where module.json was found (or its parent)
            # This moves all files and folders (including hidden) from source_content_parent_dir
            # into target_module_dir
            if [ "$source_content_parent_dir" != "$temp_extract_dir" ] && [ -d "$source_content_parent_dir" ]; then
                echo "  Moving contents from sub-directory '$source_content_parent_dir'..."
                (shopt -s dotglob && mv "$source_content_parent_dir"/* "$target_module_dir/" && shopt -u dotglob)
            elif [ -d "$temp_extract_dir" ]; then # module.json was at the root of temp_extract_dir
                echo "  Moving contents from root of temporary extract directory..."
                (shopt -s dotglob && mv "$temp_extract_dir"/* "$target_module_dir/" && shopt -u dotglob)
            else
                 echo "  Error: Source content directory '$source_content_parent_dir' or '$temp_extract_dir' not found or not a directory."
                 # Fallback or error handling
            fi

            if [ $? -ne 0 ]; then
                echo "  Error moving module contents to '$target_module_dir'. Check '$temp_extract_dir'."
            else
                echo "  Module contents successfully moved to '$target_module_dir/'."
            fi
        else
            echo "  Error: Could not find module.json within the extracted files in '$temp_extract_dir'."
            echo "  This module might be structured unusually or the ZIP might be corrupted."
            echo "  Attempting to move all contents from '$temp_extract_dir' as a fallback..."
            (shopt -s dotglob && mv "$temp_extract_dir"/* "$target_module_dir/" && shopt -u dotglob)
            if [ $? -ne 0 ]; then
                 echo "  Fallback move also failed. Contents may remain in '$temp_extract_dir'."
            else
                 echo "  Fallback move completed. Please verify the structure in '$target_module_dir'."
            fi
        fi
    fi

    # 6. Clean up
    rm -f "$zip_filename"
    rm -rf "$temp_extract_dir" # Clean up the temporary extraction directory
    rm -f "$temp_json"
    echo "Cleanup complete for $module_id."
done

echo "----------------------------------------"
echo "All processing finished."
