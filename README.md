# Windows Backup Solution

A robust PowerShell-based backup solution for Windows systems with configuration file support, wildcard path matching, and detailed logging.

## Current Version: "v3" 

# HIGHLY UNSAFE. please use the scripts under the [legacy](./legacy/) folder until I say otherwise.
## You need admin permissions to run any of the scripts. `scoop install gsudo` is a good way to get admin permissions in PowerShell. Then simply run `gsudo .\legacy\backup.ps1` to run the script with admin permissions.
Beforehand though, set origin and destination paths in the legacy v1 script manually in the header section of the file. Can't miss it.

As for the "new and improved version", right now it's getting way more complicated.
Reason: I want to support sophisticated config files and wildcards in the source directories. This is a big leap from the simple text file listing in the legacy version.


The latest version (`backup_v0.3.ps1`) introduces several improvements:
- INI-style configuration file support
- Wildcard path matching for flexible directory selection
- Preview mode to verify backup selections
- Multi-threaded copying with configurable parameters
- Comprehensive logging and backup summaries
- Space requirement verification
- Backup mode for handling locked files
- Progress tracking with percentage completion

## Quick Start

1. Download the following files:
   - `backup_v0.3.ps1` (Main script)
   - `backup.conf` (Configuration file)

2. Modify `backup.conf` to specify:
   - Source directories to backup
   - Directories/files to exclude
   - Destination path
   - Performance settings (threads, retries, etc.)

3. Run the backup:
```powershell
.\backup_v0.3.ps1
```

## Configuration File Format

The `backup.conf` file uses INI format with the following sections:

```ini
[Settings]
SourceDrive=C:\
Threads=16
RetryCount=5
RetryWait=1

[Backup Directories]
Users\*\Documents
Users\*\Desktop
# Add more directories...

[Exclude Directories]
Users\*\AppData\Local\Temp
# Add exclusions...

[Exclude Files]
# Add file patterns to exclude

[Destination]
D:\Backup\Backup-2025
```

### Wildcard Support
- Use `*` in paths to match multiple directories
- Example: `Users\*\Documents` backs up all users' Documents folders

## Command Line Parameters

```powershell
.\backup_v0.3.ps1 [-configFile <path>] [-force] [-whatif]
```

- `-configFile`: Specify alternate config file (default: backup.conf)
- `-force`: Override destination space check
- `-whatif`: Preview mode - shows what would be backed up without copying

## Space Requirements

The script automatically:
1. Calculates total size of source directories
2. Verifies available space at destination
3. Prevents backup if insufficient space (unless `-force` used)

## Logging

The script maintains two log files:
- `backup_log.txt`: Detailed operation log
- `backup_summary.txt`: Generated in each backup folder with overview

## Restore Functionality

> ⚠️ **Warning**: The restore functionality (`restore.ps1`) is currently in beta and uses a simpler format. Use with caution as improper restoration could overwrite existing files.

For restoration needs, please:
1. Create a `restore_directories.txt` file
2. List directories one per line (no wildcards)
3. Test restore on a small subset first

## Best Practices

1. Run with administrator privileges
2. Use `-whatif` to preview before actual backup
3. Ensure sufficient destination space
4. Regularly review logs
5. Test backups periodically
6. Keep configuration file updated

## Performance Tuning

Adjust in `backup.conf` [Settings] section:
- `Threads`: 1-128 (default: 16)
- `RetryCount`: 0-100 (default: 5)
- `RetryWait`: 0-60 seconds (default: 1)

## Future Development

Planned improvements:
- Enhanced restore functionality
- Compression options
- Incremental backup support
- GUI interface
- Self-contained executable

## Requirements

- Windows PowerShell 5.1 or newer
- Administrator privileges
- Sufficient destination drive space
- Network access for remote destinations

## Known Limitations

1. Source drive currently fixed to C:\ by default
2. No built-in compression
3. Basic restore functionality
4. Limited error recovery options

## Support

For issues and suggestions:
1. Check logs for error messages
2. Verify configuration syntax
3. Ensure admin privileges
4. Test with `-whatif` flag

## License

GPL-3.0 License