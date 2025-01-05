# Legacy Windows Backup Solution (v1.0)

## tl;dr Legacy means it works.

Open powershell as admin (ctrl+shift+click on terminal or so), navigate to the legacy folder, and run the script with `.\backup.ps1`.
Take look at the `backup_directories.txt` file to see what directories are being backed up.
Then adjust the source and destination paths in the [legacy/backup.ps1](backup.ps1) script right at the top.

If you are a chad, you use scoop. scoop installs gsudo. If you are a gigachad, you declare `sudo` as an alias for `gsudo` in your PowerShell `$PROFILE`. Then you can run the script with `sudo .\backup.ps1` without opening an admin terminal. 

## Philosophy: what is legacy anyway

Don't mistake this for actual legacy. This is the WORKING version of the backup script. The legacy version is the starting point for me to advance to the v3 version under [backup_v0.3.ps1](../backup_v0.3.ps1).

Use **this """legacy""" section before I declare the main folder safe to use.

This document describes the original version of the Windows backup solution, which is my simple approach with direct file listing.
It still works like a charm for basic backup needs, but lacks the advanced features of the latest version which are probably not needed for most users.

## Version: v1.0 (Legacy)

The original version (`backup.ps1`) was designed with simplicity in mind, using a straightforward text file for directory listings and minimal configuration options.

## Basic Setup

1. Required files:
   - `backup.ps1` (Main script)
   - `backup_directories.txt` (List of directories to backup)

2. Create `backup_directories.txt` with directories to backup:
```text
Users\YourUsername\Documents
Users\YourUsername\Desktop
Users\YourUsername\Pictures
Program Files\ImportantApp
```

3. Run the backup:
```powershell
.\backup.ps1
```

## Script Parameters

```powershell
.\backup.ps1 [-sourceDrive <path>] [-destinationDrive <path>]
```

Default values:
- sourceDrive: "C:\"
- destinationDrive: "D:\Backup"

## How It Worked

### Directory Listing
- Simple text file (`backup_directories.txt`)
- One directory per line
- No wildcards or pattern matching
- Relative paths from source drive root

### Backup Process
1. Read directories from `backup_directories.txt`
2. Check if destination is not a subdirectory of source
3. Verify destination drive exists
4. Copy each directory using robocopy
5. Log all operations

### Logging
- All operations logged to `backup_log.txt`
- Basic timestamp + message format
- Both successful copies and errors logged

### Robocopy Parameters Used
- `/E`: Copy subdirectories, including empty ones
- `/XO`: Exclude older files
- `/XJ`: Exclude junction points
- `/R:5`: 5 retries on fail
- `/W:1`: 1 second wait between retries

## Limitations

1. No configuration file
   - Hard-coded parameters
   - Manual source/destination changes required in script

2. No space checking
   - Could fail mid-backup if space runs out
   - No warning about required space

3. No exclusion support
   - Could not exclude specific files/folders
   - No pattern matching

4. Basic error handling
   - Simple try/catch blocks
   - Limited recovery options

5. No progress tracking
   - Only completion messages
   - No percentage indicators

6. Single-threaded operation
   - No performance optimization
   - Basic robocopy settings

## Migration to New Version

If you're using this legacy version, consider upgrading to the latest version (`backup_v0.3.ps1`) which offers:
- Configuration file support
- Wildcard matching
- Space checking
- Multi-threading
- Progress tracking
- Exclusion patterns
- Preview mode

## Historical Context

This version was designed for:
- Basic backup needs
- Single user systems
- Simple directory structures
- Minimal configuration requirements

## Support Status

This version is no longer maintained. Users should migrate to `backup_v0.3.ps1` for improved functionality and support.

## Original Syntax Example

```powershell
# Example backup_directories.txt
Users\John\Documents
Users\John\Desktop
Program Files\CustomApp
Windows\System32\drivers\etc
```

This legacy documentation is maintained for historical reference only. Please refer to the main README.md for current version documentation.