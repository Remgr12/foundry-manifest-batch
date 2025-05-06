#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads and extracts Foundry VTT modules from manifest URLs.
.DESCRIPTION
    This script fetches module information from provided manifest URLs,
    downloads the module ZIP package, creates a directory for it,
    and then unzips the package into that directory.
    It can take URLs directly as arguments or read them from a 'links.txt' file.
.PARAMETER Urls
    An array of strings, where each string is a manifest URL to process.
.PARAMETER FromFile
    A switch parameter. If specified, the script will read manifest URLs
    from a file named 'links.txt' located in the same directory as the script.
.EXAMPLE
    .\Install-Modules.ps1 "https://example.com/module1/module.json" "https://example.com/module2/module.json"
    Downloads and extracts modules from the two specified URLs.
.EXAMPLE
    .\Install-Modules.ps1 -FromFile
    Downloads and extracts modules from URLs listed in 'links.txt'.
#>
param(
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$Urls,

    [Parameter(Mandatory = $false)]
    [switch]$FromFile
)

# --- Configuration ---
$urlFile = "links.txt" # File to read URLs from when using -FromFile
$tempJsonManifest = "temp_module_manifest.ps.json" # Temporary file for initial manifest

# --- Function to display usage ---
function Show-Usage {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [-FromFile] | <manifest_url1> [manifest_url2] ..."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  <url>...       Provide one or more manifest URLs directly."
    Write-Host "  -FromFile      Read manifest URLs from the file '$urlFile' (one URL per line)."
    Write-Host "                 The '$urlFile' should be in the same directory as the script."
    Write-Host ""
}

# --- Determine URLs to process ---
$urls_to_process = [System.Collections.Generic.List[string]]::new()

if ($FromFile.IsPresent) {
    $resolvedUrlFilePath = Join-Path -Path $PSScriptRoot -ChildPath $urlFile # $PSScriptRoot is the directory of the script
    if (Test-Path $resolvedUrlFilePath) {
        Write-Host "Reading URLs from file: $resolvedUrlFilePath"
        Get-Content $resolvedUrlFilePath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and $line -notmatch '^\s*(#|$)') { # Skip empty lines and comments
                $urls_to_process.Add($line)
            }
        }
        if ($urls_to_process.Count -eq 0) {
             Write-Error "'$resolvedUrlFilePath' exists but contains no valid URLs (or only comments/empty lines)."
             exit 1
        }
        Write-Host "Found $($urls_to_process.Count) URL(s) in $resolvedUrlFilePath."
    } else {
        Write-Error "Error: Cannot read URLs from '$resolvedUrlFilePath'. File does not exist."
        exit 1
    }
} elseif ($Urls) {
    Write-Host "Reading URLs from command-line arguments."
    $urls_to_process.AddRange($Urls)
} else {
    Show-Usage
    Write-Error "Error: No manifest URLs provided and -FromFile option not used."
    exit 1
}

# --- Sanity check if we have URLs ---
if ($urls_to_process.Count -eq 0) {
     Write-Error "Error: No URLs to process."
     exit 1
}

# --- Main loop ---
$currentLocation = Get-Location # Modules will be downloaded relative to where the script is run
Write-Host "Starting module download and extraction process for $($urls_to_process.Count) URL(s) in directory: $currentLocation"

foreach ($json_url in $urls_to_process) {
    Write-Host "----------------------------------------" -ForegroundColor Green
    Write-Host "Processing manifest URL: $json_url"

    $tempJsonManifestPath = Join-Path -Path $currentLocation -ChildPath $tempJsonManifest

    # 1. Download the initial module.json file
    try {
        Invoke-WebRequest -Uri $json_url -OutFile $tempJsonManifestPath -TimeoutSec 15 -ErrorAction Stop
        Write-Host "Manifest downloaded."
    } catch {
        Write-Warning "Error: Failed to download manifest from $json_url. $($_.Exception.Message). Skipping."
        continue
    }

    # 2. Extract download URL and module ID
    $download_url = $null
    $module_id_from_manifest = $null

    try {
        $manifestContent = Get-Content $tempJsonManifestPath -Raw -ErrorAction Stop
        $manifest = $manifestContent | ConvertFrom-Json -ErrorAction Stop

        $download_url = $manifest.download
        if ($manifest.PSObject.Properties.Name -contains 'id' -and $manifest.id) {
            $module_id_from_manifest = $manifest.id
        } elseif ($manifest.PSObject.Properties.Name -contains 'name' -and $manifest.name) {
            $module_id_from_manifest = $manifest.name
        }
    } catch {
        Write-Warning "Error parsing manifest JSON from $json_url or file is empty. $($_.Exception.Message). Skipping."
        Remove-Item -Path $tempJsonManifestPath -Force -ErrorAction SilentlyContinue
        continue
    }

    # Validate extracted info
    if (-not $download_url) {
        Write-Warning "Error: Could not extract 'download' URL from manifest ($json_url). Skipping."
        Remove-Item -Path $tempJsonManifestPath -Force -ErrorAction SilentlyContinue
        continue
    }
    if (-not $module_id_from_manifest) {
        Write-Warning "Warning: Could not extract module 'id' or 'name' from manifest ($json_url). Using generic folder name."
        $timestamp = Get-Date -Format "yyyyMMddHHmmssfff"
        $module_id_from_manifest = "unknown_module_$timestamp"
    }

    Write-Host "Module ID/Name: $module_id_from_manifest"
    Write-Host "Download URL: $download_url"

    # Define zip filename and module directory path
    $zip_filename = "$($module_id_from_manifest).zip"
    $zip_filepath = Join-Path -Path $currentLocation -ChildPath $zip_filename
    $module_dir = Join-Path -Path $currentLocation -ChildPath $module_id_from_manifest

    # 3. Download the actual module ZIP file
    Write-Host "Downloading module package..."
    try {
        Invoke-WebRequest -Uri $download_url -OutFile $zip_filepath -TimeoutSec 180 -ErrorAction Stop
        Write-Host "Module package downloaded: $zip_filepath"
    } catch {
        Write-Warning "Error: Failed to download module package from $download_url. $($_.Exception.Message). Skipping."
        Remove-Item -Path $tempJsonManifestPath -Force -ErrorAction SilentlyContinue
        continue
    }

    # 4. Create the destination folder
    Write-Host "Creating directory: $module_dir"
    try {
        if (-not (Test-Path $module_dir)) {
            New-Item -ItemType Directory -Path $module_dir -ErrorAction Stop | Out-Null
        } else {
            Write-Host "Directory '$module_dir' already exists."
        }
    } catch {
        Write-Warning "Error: Failed to create directory '$module_dir'. $($_.Exception.Message). Skipping unzip."
        Remove-Item -Path $tempJsonManifestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zip_filepath -Force -ErrorAction SilentlyContinue
        continue
    }

    # 5. Unzip the package into the folder
    Write-Host "Unzipping $zip_filepath into $module_dir/"
    try {
        Expand-Archive -Path $zip_filepath -DestinationPath $module_dir -Force -ErrorAction Stop # -Force will overwrite existing files
        Write-Host "Successfully extracted."
        Remove-Item -Path $zip_filepath -Force -ErrorAction SilentlyContinue # Clean up ZIP on success
    } catch {
        Write-Warning "Error: Failed to unzip '$zip_filepath' into '$module_dir'. $($_.Exception.Message). Manual check required (zip kept)."
    }

    # Clean up the temporary initial JSON file
    Remove-Item -Path $tempJsonManifestPath -Force -ErrorAction SilentlyContinue
done

Write-Host "----------------------------------------" -ForegroundColor Green
Write-Host "Processing complete."
