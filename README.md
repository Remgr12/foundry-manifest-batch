# Foundry VTT Module Downloader Script

This document provides instructions for using scripts to download and extract Foundry VTT modules using their manifest URLs. We offer two versions:

1.  A **bash script (`install.sh`)** for **Linux and macOS users**.
2.  A **PowerShell script (`Install-Modules.ps1`)** for **Windows execution**.

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
    ./install.sh [URL1] [URL2] ...
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

## Using the Windows Batch Script (`install_modules.bat`)

### Prerequisites (Batch - CRUCIAL!)

This script **requires** the following external command-line tools to be installed and accessible in your system's `PATH` environment variable, OR placed in the **same directory** as the `install_modules.bat` script:

* **`curl.exe`**: For downloading files. Modern Windows 10/11 often include this.
    * To check: Open Command Prompt and type `curl --version`.
    * If not found, download from (https://curl.se/windows/).
* **`jq.exe`**: Essential for parsing JSON manifest files. This tool is **not** included with Windows.
    * Download `jq.exe` (e.g., `jq-win64.exe`, then rename to `jq.exe`) from (https://jqlang.github.io/jq/download/).
* **`tar.exe`**: For unzipping `.zip` files. Modern Windows 10/11 often include this, providing basic archive operations.
    * To check: Open Command Prompt and type `tar --version`.
    *(Alternatively, if `tar.exe` is missing or problematic, you could modify the script to use `7za.exe` from 7-Zip, which is a very robust archiver, but you'd need to install 7-Zip and adjust the unzip command within the script code.)*

**Without `curl.exe`, `jq.exe`, and `tar.exe` (or a suitable replacement for `tar.exe`) correctly set up, this Batch script will NOT function.** The script includes a reminder and a `PAUSE` at the beginning for you to acknowledge this.

### Setup (Batch)

1.  **Obtain the Script**: Ensure you have the `install_modules.bat` Batch script code.
2.  **Place Prerequisites**: Ensure `curl.exe`, `jq.exe`, and `tar.exe` are either in your system PATH or in the modules directory.

### How to Run (`install_modules.bat`)

1.  **Open Command Prompt (`cmd.exe`)**.
2.  **Navigate to Script Directory**: Use `cd` to go to the folder where your modules folder is saved.
    ```cmd
    cd C:\Path\To\Your\Modules
    ```
3.  **Execute the Script**:
    You can provide manifest URLs in two ways:

    * **Directly as Command-Line Arguments**:
        ```cmd
        install_modules.bat "URL1" "URL2" ...
        ```

    * **From a `links.txt` File (using the `-f` flag)**:
        ```cmd
        install_modules.bat -f
        ```
        `links.txt` should be in the same directory as `install_modules.bat`.

#### `links.txt` File Format (for Batch script)

If using the `-f` option, create `links.txt` in the same directory as `install_modules.bat`:
* Each manifest URL on a new line.
* Lines starting with `#` are intended as comments (the script makes a basic attempt to skip them).
* Empty lines are intended to be skipped.
