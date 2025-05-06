# Foundry VTT Module Downloader Scripts

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

## Using the PowerShell Script (`Install-Modules.ps1`)
*(For Windows - Native Execution)*

### Prerequisites (PowerShell)

Before running `Install-Modules.ps1`, ensure your Windows environment meets these requirements:

* **PowerShell 5.1 or newer**: This is standard on Windows 10 and Windows 11. You can check your version by opening PowerShell and typing `$PSVersionTable.PSVersion`.
* **Execution Policy**: By default, PowerShell's execution policy might prevent you from running local scripts. If you encounter an error related to script execution being disabled, you may need to adjust this policy. To do this (you only need to do it once):
    1.  Open PowerShell **as Administrator**.
    2.  Run the command: `Set-ExecutionPolicy RemoteSigned`
    3.  When prompted, type `Y` and press Enter.
    *(You can check your current policy with `Get-ExecutionPolicy`.)*

### Setup (PowerShell)

1.  **Obtain the Script**: Ensure you have the `Install-Modules.ps1` PowerShell script.
2.  **Save the Script**: Save the file into your modules directory.

### How to Run (`Install-Modules.ps1`)

1.  **Open PowerShell**: You can open a normal PowerShell window.
2.  **Navigate to Script Directory**: Use the `cd` command to go to the folder where you saved `Install-Modules.ps1`. For example:
    ```powershell
    cd "C:\Path\To\Your\Scripts"
    ```
3.  **Execute the Script**:
    You can provide manifest URLs in two ways:

    * **Directly as Command-Line Arguments**:
        ```powershell
        .\Install-Modules.ps1 "URL1" "URL2" ...
        ```

    * **From a `links.txt` File (using the `-FromFile` switch)**:
        ```powershell
        .\Install-Modules.ps1 -FromFile
        ```
        This tells the script to read URLs from a file named `links.txt`. This `links.txt` file **must be located in the same directory as the `Install-Modules.ps1` script itself**, as the script uses `$PSScriptRoot` to find it.

**Command-Line Options:**

* **`"URL1" "URL2" ...`**: One or more manifest URLs (these are positional parameters).
* **`-FromFile`**: A switch parameter. If present, the script reads URLs from `links.txt`.

If no URLs are provided (either directly or via `-FromFile`), a usage message is displayed by the script.

#### `links.txt` File Format (for PowerShell script)

If using the `-FromFile` option, create a plain text file named `links.txt` in the *same directory* as your `Install-Modules.ps1` script:
* Each manifest URL should be on a new line.
* Lines starting with `#` are treated as comments and will be ignored.
* Empty lines will also be ignored.
