# File: restore.ps1

# PowerShell Restore Script

param(
    [string]$sourceDrive = "<your destination>",
    [string]$destinationDrive = "C:\"
)

# Function to write log with timestamp
function Write-Log {
    Param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath restore_log.txt -Append
}

# Read Directories to Restore from a File
if (Test-Path -Path "restore_directories.txt") {
    $directoriesToRestore = Get-Content "restore_directories.txt"
}
else {
    Write-Host "Restore directories file not found." -ForegroundColor Red
    exit
}

# Check if Source Drive Exists
if (-Not (Test-Path -Path $sourceDrive)) {
    Write-Host "Source drive does not exist. Check the drive letter." -ForegroundColor Red
    exit
}

# Restore Process
foreach ($dir in $directoriesToRestore) {
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    $destPath = Join-Path -Path $destinationDrive -ChildPath $dir

    if (Test-Path -Path $sourcePath) {
        try {
            robocopy $sourcePath $destPath /E /XO /XJ /R:5 /W:1 /LOG+:restore_log.txt
            Write-Log "Restored $sourcePath to $destPath"
        }
        catch {
            Write-Host "Error restoring $sourcePath : $($_)" -ForegroundColor Red
            Write-Log "Error restoring $sourcePath : $($_)"
        }
    }
    else {
        Write-Host "Skipping $sourcePath as it does not exist in backup." -ForegroundColor Yellow
        Write-Log "Skipping $sourcePath as it does not exist in backup."
    }
}

Write-Host "Restore completed successfully!" -ForegroundColor Green
Write-Log "Restore completed successfully!"