# Foundry VTT Module Downloader Script

This document provides instructions for using scripts to download and extract Foundry VTT modules using their manifest URLs. There are two versions:

1.  A **bash script (`install.sh`)** for **Linux and macOS users**.
2.  A **bat script (`install_modules.bat`)** for **Windows execution**.

Choose the script appropriate for your operating system and environment.

## General Purpose

These scripts automate the following process for each provided manifest URL:

1.  **Fetch Initial Manifest:** Downloads the `module.json` file from the given URL.
2.  **Extract Information:** Reads this manifest to find:
    * The direct URL of the module's ZIP package (usually from a `download` field).
    * The module's unique `id` or `name` (used for naming the download directory).
3.  **Download Module Package:** Downloads the actual module ZIP file.
4.  **Create Directory:** Creates a local directory named after the module's `id` or `name` in the current working directory.
5.  **Unzip Package:** Extracts the module's contents into this new directory.
6.  **Cleanup:** Deletes temporary downloaded files (the initial manifest and the ZIP package after successful extraction).

---

## Chapter 1: Bash Script (`install.sh`)
*(For Linux and macOS)*


### Prerequisites (Bash)

Before running `install.sh`, ensure you have the following command-line tools installed:

* **`bash`**: The shell interpreter (standard on Linux and macOS).
* **`wget`**: For downloading files from URLs.
* **`jq`**: A command-line JSON processor, used to read the manifest files.
* **`unzip`**: For extracting ZIP archives.

**Typical Installation Commands:**
* **Debian/Ubuntu:** `sudo apt update && sudo apt install wget jq unzip`
* **Fedora/RHEL:** `sudo dnf install wget jq unzip`
* **macOS (using Homebrew):** `brew install wget jq unzip`

### Setup (Bash)

1.  **Save the Script:** Ensure the code for your bash script is saved as `install.sh` in your modules directory.
2.  **Make it Executable:** Open your terminal, navigate to the modules directory, and run:
  
    ```bash
    chmod +x install.sh
    ```

### How to Run (`install.sh`)

Execute the script from your terminal. You can provide manifest URLs in two ways:

1.  **Directly as Command-Line Arguments:**
    ```bash
    ./install.sh "URL1" "URL2" ...
    ```

2.  **From a `links.txt` File (using the `-f` flag):**
    ```bash
    ./install.sh -f
    ```
    This tells the script to read URLs from a file named `links.txt` located in the same directory where the script is run.

#### `links.txt` File Format (for Bash script)

If using the `-f` option, create `links.txt` in the same directory as `install.sh`:
* Each manifest URL should be on a new line.
* Empty lines are ignored.
