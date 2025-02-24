# WordPress Remote Migrate Script

This script provides a CLI solution to **migrate a WordPress site** from a remote host to your local environment taking care of most common needs. Whether you need to **clone a WordPress site**, **copy from a remote host**, or simply create a backup of your remote WordPress installation, this tool streamlines the process. It handles file synchronization (plugins, themes, uploads), database migration, and post-pull adjustments with a good level of customizations.

> **Note:**  
> This script is designed for UNIX-like systems (Linux, macOS, etc.). If you are using Windows, please run it within a UNIX-like environment (such as WSL, Git Bash, or Cygwin).

---

## Features

- **Flexible Synchronization Options:**  
  Choose to skip, fully download, or selectively synchronize plugins, themes, and uploads. This allows you to **replicate your remote WordPress site** exactly as needed.

- **Skip unwanted files.**  
  For large sites, you can skip files exceeding a specified file-size threshold and exclude specific file types (such as videos, PDFs, and ZIP files) to avoid downloading unnecessary data.

- **Sync only what you need**  
  You can easily choose to copy between:
  - Only plugins (all or only enabled)
  - Only themes  (all or only enabled)
  - Only uploads
      - Cap by file-size
      - Skipping specific file-types
      - Only some year folders
  - Only database, removing unwanted tables

- **Database Handling:**  
  Optionally download, clean, and import the remote database with support for excluding specific tables. This feature is essential when you need to **migrate a WordPress site** without carrying over unwanted data.

- **Do not copy what already exists**
  - The script copies over only files that don't exist in your local install.

- **Post-Pull Plugin Management:**  
  Automatically deactivates a list of default plugins (space-separated) after pulling the site, ensuring that your local clone of the WP site runs smoothly.

- **Version Matching:**  
  Optionally checks and updates your local WordPress version to match the remote version, providing a consistent environment when you **copy a remote WP site**.

- **Interactive Remote Connection Setup:**  
  If a per-site configuration file is not found, the script will prompt you to enter remote credentials, helping you **copy your WordPress site from a remote host** effortlessly.

- **Automatic WP Root Detection:**
  Run the script from any subdirectory; it will locate the WordPress root by finding **wp-config.php**, making it an ideal tool to **clone a WordPress site** or **migrate your WP site** seamlessly.

---

## Requirements

Ensure the following tools are installed to **migrate your WordPress site** successfully:

- **rsync**  
  - **Installation:**  
    - Linux: Install via your package manager (e.g., `sudo apt install rsync` or `sudo yum install rsync`).
    - macOS: Install via Homebrew using `brew install rsync`.  
  - More Info: [rsync official site](https://www.rsync.samba.org/)

- **WP-CLI**  
  - **Installation:** Follow the instructions on the [WP-CLI installation guide](https://wp-cli.org/#installing).

- **sed**  
  - Typically pre-installed on UNIX systems.  
  - More Info: [GNU sed Documentation](https://www.gnu.org/software/sed/)

- **SSH & SCP**  
  - Ensure OpenSSH is installed (usually pre-installed on UNIX systems).

- **UNIX-like Environment:**  
  - The script must be run on a UNIX-like system. Windows users should use environments such as WSL, Git Bash, or Cygwin.

---

## Installation

For most users, the recommended way to obtain the script is by downloading the latest release ZIP file from the Releases page. This provides a stable, verified version of the script without the extra repository history.

After downloading the release package, remember to:

1. Make the script executable.

    ```bash
    chmod +x wp-remote-migrate.sh
    ```

2. *(Optional)* Add the script folder to your PATH so you can execute it globally from any directory. Alternatively, you can create a symbolic link or an alias in your shell configuration.

   2.1 Add the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc) replacing the path with your script folder path:
   ```bash
   export PATH="/path/to/your/script/folder/:$PATH"
   ```

   After updating your shell configuration file, reload it by running:
   ```bash
   source ~/.bashrc  # or source ~/.zshrc
   ```

   2.2 Instead, you can create a symbolic link in your bin folder. 
   ```bash
   sudo ln -s $(pwd)/wp-remote-migrate.sh /usr/local/bin/wp-remote-migrate
   ```

   2.3 Or you can even create an alias, by adding the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc). Make sure to replace `path/to/your/` with your local path for this script:
   ```bash
   alias wp-remote-migrate='path/to/your/wp-remote-migrate.sh'
   ```

   After updating your shell configuration file, reload it by running:
   ```bash
   source ~/.bashrc  # or source ~/.zshrc
   ```

3. Confirm the CLI command is working.
   
   Navigate to a WordPress site with a running local server and run your command:
   ```bash
   wp-remote-migrate.sh # or wp-remote-migrate if you have added a symbolic link or an alias.
   ```

   If the script is correctly installed, you'll see a prompt below, confirming that the setup is complete and the CLI command is working.
   ```bash
   🌐 Enter Remote Host (e.g., 123.123.123.123):
   ```

---

**Repository Settings for Contributors**

To maintain a clean and secure development workflow, contributors are encouraged to fork the repository and submit pull requests. 

---

## Configuration

### Remote Credentials

- The script looks for a per-site configuration file (named **.remote_wp_credentials**) in the WordPress root folder.

  ```bash
  REMOTE_HOST="123.123.123.123"
  REMOTE_PORT="22"
  REMOTE_USER="your_ssh_user"
  REMOTE_PATH="~/public"
  LOCAL_SITE_URL="https://mysite.local"
  ```
- **You don't need to create this file upfront** because, on the first run, you will be prompted to enter the credentials above. The file is then created automatically and is used for subsequent runs, so you won't need to re-enter your remote credentials every time.

- For security reasons, the remote user's SSH password is not stored in this file; it will be requested each time the script connects to the server. Alternatively, you can use an SSH key with proper privileges on the server.

### Default Variables File

The file **pull_wp_site_default.sh** in the same script folder contains default settings used by the script. Update it with your own requirements. Examples include:

- **DEFAULT_MAX_SIZE:** Maximum file size for uploads (e.g., `"2m"`).
- **DEFAULT_EXCLUDED_EXTENSIONS:** File extensions to exclude from uploads (e.g., `"mp4 wmv mkv avi pdf log zip"`).
- **DEFAULT_TABLES_TO_EXCLUDE:** A **comma-separated** list of database tables to exclude during export.
- **DEFAULT_PLUGINS_TO_DEACTIVATE:** A **space-separated** list of plugins to automatically deactivate after pulling the site.

---

## Usage

1. **Run from Anywhere Within Your WordPress Site:**  
   You can execute the script from any folder inside your WordPress installation; it will automatically locate the root folder (where **wp-config.php** is located). This feature is perfect if you need to **clone a WP site** from a remote host.

2. **Remote Access Authentication:**  
   When accessing the remote host, the script will prompt you for a password unless you have set up passwordless authentication using an authorized SSH key. This ensures a secure way to **copy your WordPress site from a remote host**.

3. **Interactive Prompts:**  
   The script will guide you through entering remote credentials (if no per-site settings file is found) and selecting options for synchronizing plugins, themes, uploads, and the remote database. You will have the opportunity to confirm your settings before the synchronization process begins, making it a straightforward tool to **clone your WordPress site**.

4. **Uploads Selection:**
   If you are copying over the uplods folder, the script will list the available upload year folders on the remote host and prompt you to specify which years should be downloaded. You can choose to download all or select only specific years, giving you fine-grained control over which parts of the media library to include in your **WordPress migration**.


---

## Troubleshooting

- **WordPress is not installed or can't run WP-CLI:**  

```
❌ WordPress is NOT installed in /Users/leomuniz/Sites/nextfriday.local or could not run WP CLI.
```
  If you receive an error that the WordPress folder is invalid or WP-CLI was not found, especially when using MAMP, check your **wp-config.php** file.
  In MAMP, WordPress sites are often configured with **"localhost"** as the database host, but WP-CLI may fail to work correctly with **"localhost"**. If you encounter issues, update the database host to **"127.0.0.1"**.

- **Rsync Version:**  
  The script requires an rsync version higher than 3.1.0. If you receive a version-related error, update rsync accordingly.

- **SSH Connectivity:**  
  Ensure your SSH credentials (host, port, and user) are correct and that you can connect to the remote server.

- **WP-CLI Issues:**  
  Verify that WP-CLI is installed and accessible in your environment.

---

## Contributing

Contributions, issues, and feature requests are welcome. Please open an issue or submit a pull request on the [GitHub repository](https://github.com/leomuniz/wp-remote-migrate/issues/).

---

## License

This project is licensed under the [MIT License](LICENSE).
