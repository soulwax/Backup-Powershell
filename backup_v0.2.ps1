# File: backup_v0.2.ps1

# PowerShell Backup Script V2
# Enhanced version with proper INI config handling (backup.conf) as an intermediate to the v0.3 version.

param(
    [string]$configFile = "backup.conf",
    [switch]$force = $false # override destination space check
)

# Function to write log with timestamp
function Write-Log {
    Param ([string]$message, [string]$color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath backup_log.txt -Append
    Write-Host "$timestamp - $message" -ForegroundColor $color
}

# Function to parse INI configuration file
function Parse-IniFile {
    param([string]$filePath)
    
    $iniData = @{}
    $currentSection = ""
    
    Get-Content $filePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -and !$line.StartsWith("#")) {
            # Section header
            if ($line -match "^\[(.*)\]$") {
                $currentSection = $matches[1]
                $iniData[$currentSection] = @()
            }
            # Key-value pair or list item
            elseif ($currentSection) {
                $iniData[$currentSection] += $line
            }
        }
    }
    
    return $iniData
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
    exit 1
}

# Verify config file exists
if (-not (Test-Path $configFile)) {
    Write-Log "Configuration file '$configFile' not found." "Red"
    exit 1
}

# Parse configuration file
$config = Parse-IniFile $configFile

# Validate required sections
$requiredSections = @('Backup Directories', 'Exclude Directories', 'Exclude Files', 'Destination')
foreach ($section in $requiredSections) {
    if (-not $config.ContainsKey($section)) {
        Write-Log "Missing required section [$section] in configuration file" "Red"
        exit 1
    }
}

# Get source and destination paths
$sourceDrive = "C:\" # Default source drive
$destinationPath = $config['Destination'][0]

# Validate destination path
if (-not $destinationPath) {
    Write-Log "Destination path not specified in configuration file" "Red"
    exit 1
}

if (-not (Test-Path -Path (Split-Path -Parent $destinationPath))) {
    Write-Log "Destination parent directory does not exist: $destinationPath" "Red"
    exit 1
}

# Process exclusions
$excludeDirs = $config['Exclude Directories']
$excludeFiles = $config['Exclude Files']

# Build robocopy exclusion parameters
$excludeParams = @()
foreach ($dir in $excludeDirs) {
    $excludeParams += "/XD"
    $excludeParams += "`"$dir`""
}
foreach ($file in $excludeFiles) {
    $excludeParams += "/XF"
    $excludeParams += "`"$file`""
}

# Calculate total size and check space
$totalSize = 0
foreach ($dir in $config['Backup Directories']) {
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    if (Test-Path -Path $sourcePath) {
        $totalSize += Get-DirectorySize -path $sourcePath
    }
}

# Check available space
$destinationDrive = (Split-Path -Qualifier $destinationPath) + "\"
$freeSpace = (Get-PSDrive -Name $destinationDrive[0]).Free
if ($freeSpace -lt $totalSize -and -not $force) {
    Write-Log "Insufficient space on destination drive. Required: $([math]::Round($totalSize/1GB, 2)) GB, Available: $([math]::Round($freeSpace/1GB, 2)) GB" "Red"
    Write-Log "Use -force parameter to override this check." "Yellow"
    exit 1
}

# Create backup timestamp and final destination path
$backupTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$destinationPath = Join-Path -Path $destinationPath -ChildPath $backupTimestamp
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

# Initialize progress counter
$currentDir = 0
$totalDirs = $config['Backup Directories'].Count

# Backup Process
foreach ($dir in $config['Backup Directories']) {
    $currentDir++
    $progress = [math]::Round(($currentDir / $totalDirs) * 100, 2)
    
    $sourcePath = Join-Path -Path $sourceDrive -ChildPath $dir
    $destPath = Join-Path -Path $destinationPath -ChildPath $dir

    if (Test-Path -Path $sourcePath) {
        Write-Log "[$progress%] Processing: $sourcePath" "Cyan"
        try {
            # Create parent directories
            New-Item -ItemType Directory -Path (Split-Path -Parent $destPath) -Force -ErrorAction SilentlyContinue | Out-Null
            
            # Build robocopy command with exclusions
            $robocopyArgs = @(
                $sourcePath,
                $destPath,
                "/E", # Copy subdirectories, including empty ones
                "/XO", # Exclude older files
                "/XJ", # Exclude junction points
                "/R:5", # Retry 5 times
                "/W:1", # Wait 1 second between retries
                "/NP", # No progress
                "/MT:16", # Use 16 threads
                "/Z", # Copy in restartable mode
                "/B", # Backup mode
                "/LOG+:backup_log.txt"
            ) + $excludeParams

            # Execute robocopy
            $result = & robocopy $robocopyArgs
            
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
Destination: $destinationPath
Total Size: $([math]::Round($totalSize/1GB, 2)) GB
Directories Processed: $totalDirs
Excluded Directories: $(($excludeDirs | Where-Object { $_ }) -join ', ')
Excluded Files: $(($excludeFiles | Where-Object { $_ }) -join ', ')
"@
$summary | Out-File -FilePath (Join-Path -Path $destinationPath -ChildPath "backup_summary.txt")

Write-Log "Backup completed! Summary saved to backup_summary.txt" "Green"