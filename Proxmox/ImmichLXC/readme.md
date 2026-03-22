# Immich Configuration Script

This script is designed to configure the Immich application running in an LXC container on Proxmox. It performs several tasks including stopping services, checking mount points, ensuring target directory structures, fixing environment variables, migrating existing data, creating symlinks, and restarting services.

## Prerequisites

- Ensure that the necessary directories (`/mnt/immich_appconfig`, `/mnt/immich_ingest`, `/mnt/immich_library`) are mounted correctly on your NAS.
- Make sure that the Immich services (`immich-web` and `immich-ml`) are installed and available.

## Usage

1. Save this script as `Immich_Config.sh`.
2. Make the script executable:
   ```bash
   chmod +x Immich_Config.sh
   ```
3. Run the script with superuser privileges:
   ```bash
   sudo ./Immich_Config.sh
   ```

## Script Details

### Stopping Services
The script starts by stopping the Immich services to ensure a clean configuration process.

### Checking Mount Points
It checks if the required directories exist. If any directory does not exist, it will prompt you to mount your NAS first and exit.

### Ensuring Target Structure
The script ensures that the necessary subdirectories within the target directories are created.

### Fixing .env File
If the `IMMICH_MEDIA_LOCATION` variable exists in the `.env` file, it updates its value. If not, it adds the variable with the specified upload root path.

### Migrating Existing Data
The script attempts to migrate existing data from the old locations to the new target directories if they exist.

### Creating Symlinks
It creates symbolic links between the old and new locations for easy access and management.

### Fixing Machine-Learning Symlink
It updates the machine-learning symlink to point to the correct upload root.

### Adjusting Ownership
The script adjusts the ownership of the Immich application directory to ensure proper permissions.

### Updating Media Paths in DB
If the `immich-admin` tool is available, it updates the media paths in the database.

### Restarting Services
Finally, it restarts the Immich services and displays the last 10 lines of the web log for verification.

## Contributing

Feel free to contribute by submitting pull requests or issues if you encounter any problems or have suggestions for improvements.

## License

This script is released under the [MIT License](LICENSE).