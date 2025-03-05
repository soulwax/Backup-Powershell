# File: legacy/backup.ps1

# PowerShell Backup Script

param(
    [string]$sourceDrive = "C:\",
    [string]$destinationDrive = "D:\Backup\")

# Function to write log with timestamp
function Write-Log {
    Param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath backup_log.txt -Append
}

# Check destination is not a subdirectory of source
if ($destinationDrive.StartsWith($sourceDrive)) {
    Write-Host "Destination cannot be a subdirectory of the source. Choose a different destination." -ForegroundColor Red
    exit
}

# Read Directories to Backup from a File
if (Test-Path -Path "backup_directories.txt") {
    $directoriesToBackup = Get-Content "backup_directories.txt"
}
else {
    Write-Host "Backup directories file not found." -ForegroundColor Red
    exit
}

# Check if Destination Drive Exists
if (-Not (Test-Path -Path $destinationDrive)) {
    Write-Host "Destination drive does not exist. Check the drive letter." -ForegroundColor Red
    exit
}

# Backup Process
foreach ($dir in $directoriesToBackup) {
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    $destPath = Join-Path -Path $destinationDrive -ChildPath $dir

    if (Test-Path -Path $sourcePath) {
        try {
            robocopy $sourcePath $destPath /E /XO /XJ /R:5 /W:1 /LOG+:backup_log.txt
            Write-Log "Copied $sourcePath to $destPath"
        }
        catch {
            Write-Host "Error copying $sourcePath : $_" -ForegroundColor Red
            Write-Log "Error copying $sourcePath : $_"
        }
    }
    else {
        Write-Host "Skipping $sourcePath as it does not exist." -ForegroundColor Yellow
        Write-Log "Skipping $sourcePath as it does not exist."
    }
}

Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Log "Backup completed successfully!"