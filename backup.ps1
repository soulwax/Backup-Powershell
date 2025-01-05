# File: backup.ps1
# Slightly more advanced version compared to legacy but still lacks ini style configuration file support and destination space check.
# param()'s need to be updated by hand to reflect the new parameters.

# PowerShell Backup Script

param(
    [string]$sourceDrive = "C:\", # extract from backup.conf
    [string]$destinationDrive = "D:\Backup", # extract from backup.conf
    [switch]$force = $false # override destination space check
)

# Function to write log with timestamp
function Write-Log {
    Param ([string]$message, [string]$color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath backup_log.txt -Append
    Write-Host "$timestamp - $message" -ForegroundColor $color
}

# Function to get directory size
function Get-DirectorySize {
    param ([string]$path)
    $size = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
    return $size.Sum
}

# Check if running with administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "This script requires administrator privileges to access all files." "Red"
    exit
}

# Check destination is not a subdirectory of source
if ($destinationDrive.StartsWith($sourceDrive)) {
    Write-Log "Destination cannot be a subdirectory of the source. Choose a different destination." "Red"
    exit
}

# Read Directories to Backup from a File
# Allow both backup and restore file names
$directoryFiles = @("backup.conf", "restore.conf")
$fileFound = $false

foreach ($file in $directoryFiles) {
    if (Test-Path -Path $file) {
        # Read content and filter out comments and empty lines
        $directoriesToBackup = Get-Content $file | 
        Where-Object { 
            $_.Trim() -ne "" -and 
            -not $_.Trim().StartsWith("#")
        }
        
        if ($directoriesToBackup.Count -eq 0) {
            Write-Log "No valid directories specified in $file" "Red"
            exit
        }
        
        $fileFound = $true
        break
    }
}

if (-not $fileFound) {
    Write-Log "No directory list file found. Please create backup.conf or restore.conf" "Red"
    exit
}

# Check if Destination Drive Exists
if (-Not (Test-Path -Path $destinationDrive)) {
    Write-Log "Destination drive does not exist. Check the drive letter." "Red"
    exit
}

# Calculate required space
$totalSize = 0
$existingSize = 0
foreach ($dir in $directoriesToBackup) {
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    if (Test-Path -Path $sourcePath) {
        $totalSize += Get-DirectorySize -path $sourcePath
    }
}

# Check available space
$destinationDrive = (Split-Path -Qualifier $destinationDrive) + "\"
$freeSpace = (Get-PSDrive -Name $destinationDrive[0]).Free
if ($freeSpace -lt $totalSize -and -not $force) {
    Write-Log "Insufficient space on destination drive. Required: $([math]::Round($totalSize/1GB, 2)) GB, Available: $([math]::Round($freeSpace/1GB, 2)) GB" "Red"
    Write-Log "Use -force parameter to override this check." "Yellow"
    exit
}

# Create backup timestamp
$backupTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$destinationDrive = Join-Path -Path $destinationDrive -ChildPath $backupTimestamp

# Create destination directory
New-Item -ItemType Directory -Path $destinationDrive -Force | Out-Null

# Initialize progress counter
$currentDir = 0
$totalDirs = $directoriesToBackup.Count

# Backup Process
foreach ($dir in $directoriesToBackup) {
    $currentDir++
    $progress = [math]::Round(($currentDir / $totalDirs) * 100, 2)
    
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    $destPath = Join-Path -Path $destinationDrive -ChildPath $dir

    if (Test-Path -Path $sourcePath) {
        Write-Log "[$progress%] Processing: $sourcePath" "Cyan"
        try {
            # Create parent directories if they don't exist
            New-Item -ItemType Directory -Path (Split-Path -Parent $destPath) -Force -ErrorAction SilentlyContinue | Out-Null
            
            # Robocopy parameters:
            # /E - Copy subdirectories, including empty ones
            # /XO - Exclude older files
            # /XJ - Exclude junction points and symbolic links
            # /R:5 - Retry 5 times
            # /W:1 - Wait 1 second between retries
            # /NP - No progress (reduces log size)
            # /MT:16 - Use 16 threads for faster copying
            # /Z - Copy files in restartable mode
            # /B - Backup mode (override file access permissions)
            $result = robocopy $sourcePath $destPath /E /XO /XJ /R:5 /W:1 /NP /MT:16 /Z /B /LOG+:backup_log.txt
            
            # Check robocopy exit code
            $exitCode = $LASTEXITCODE
            if ($exitCode -ge 8) {
                Write-Log "Warning: Some files in $sourcePath may not have been copied (Exit code: $exitCode)" "Yellow"
            }
            else {
                Write-Log "Successfully copied $sourcePath" "Green"
            }
        }
        catch {
            Write-Log "Error copying $sourcePath : $_" "Red"
        }
    }
    else {
        Write-Log "Skipping $sourcePath as it does not exist." "Yellow"
    }
}

# Create summary file
$summary = @"
Backup Summary
-------------
Date: $(Get-Date)
Source Drive: $sourceDrive
Destination: $destinationDrive
Total Size: $([math]::Round($totalSize/1GB, 2)) GB
Directories Processed: $totalDirs
"@
$summary | Out-File -FilePath (Join-Path -Path $destinationDrive -ChildPath "backup_summary.txt")

Write-Log "Backup completed! Summary saved to backup_summary.txt" "Green"