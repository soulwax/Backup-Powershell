# File: backup_v0.3.ps1
# PowerShell Backup Script V0.3
# Dangerously incomplete version with wildcard support and improved config handling

param(
    [string]$configFile = "backup.conf",
    [switch]$force = $false, # override destination space check
    [switch]$whatif = $false # preview mode without actual copying
)

# Function to write log with timestamp
function Write-Log {
    Param (
        [string]$message,
        [string]$color = "White",
        [switch]$noOutput
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath backup_log.txt -Append
    if (-not $noOutput) {
        Write-Host "$timestamp - $message" -ForegroundColor $color
    }
}

# Function to convert wildcard path to regex pattern
function Convert-WildcardToRegex {
    param([string]$wildcardPath)
    
    $regex = [regex]::Escape($wildcardPath)
    $regex = $regex.Replace("\*", ".*")
    return "^" + $regex + "$"
}

# Function to expand wildcard paths
function Expand-WildcardPath {
    param(
        [string]$basePath,
        [string]$wildcardPath
    )
    
    $parts = $wildcardPath.Split('\')
    $currentPath = $basePath
    $results = @()
    
    # Handle the path parts one at a time
    $tempPath = ""
    foreach ($part in $parts) {
        if ($part -contains "*") {
            # If part contains wildcard, get matching directories
            $searchPath = Join-Path $currentPath $tempPath
            $pattern = Convert-WildcardToRegex $part
            try {
                $matches = Get-ChildItem -Path $searchPath -Directory |
                Where-Object { $_.Name -match $pattern }
                foreach ($match in $matches) {
                    $remainingPath = $wildcardPath.Substring($wildcardPath.IndexOf($part) + $part.Length)
                    if ($remainingPath) {
                        $results += Expand-WildcardPath $match.FullName $remainingPath.TrimStart('\')
                    }
                    else {
                        $results += $match.FullName
                    }
                }
                return $results
            }
            catch {
                Write-Log "Error expanding wildcard path: $_" "Yellow" -noOutput
                return @()
            }
        }
        else {
            $tempPath = Join-Path $tempPath $part
        }
    }
    
    return @(Join-Path $currentPath $tempPath)
}

# Function to read INI configuration file
function Read-IniFile {
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

# Function to resolve paths with wildcards
function Resolve-WildcardPaths {
    param(
        [string]$basePath,
        [string[]]$paths
    )
    
    $resolvedPaths = @()
    foreach ($path in $paths) {
        if ($path -match "\*") {
            $expanded = Expand-WildcardPath $basePath $path
            $resolvedPaths += $expanded
        }
        else {
            $resolvedPaths += Join-Path $basePath $path
        }
    }
    return $resolvedPaths
}

# Function to get directory size
function Get-DirectorySize {
    param ([string]$path)
    $size = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
    return $size.Sum
}

# Verify config file exists and parse it
if (-not (Test-Path $configFile)) {
    Write-Log "Configuration file '$configFile' not found." "Red"
    exit 1
}

# Parse configuration file
$config = Read-IniFile $configFile

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

# Resolve all paths
$backupDirs = Resolve-WildcardPaths $sourceDrive $config['Backup Directories']
$excludeDirs = Resolve-WildcardPaths $sourceDrive $config['Exclude Directories']
$excludeFiles = Resolve-WildcardPaths $sourceDrive $config['Exclude Files']

# Preview mode
if ($whatif) {
    Write-Log "PREVIEW MODE - No files will be copied" "Yellow"
    Write-Log "The following directories will be backed up:" "White"
    $backupDirs | ForEach-Object { Write-Log "  $_" "Cyan" }
    Write-Log "`nThe following directories will be excluded:" "White"
    $excludeDirs | ForEach-Object { Write-Log "  $_" "Yellow" }
    Write-Log "`nThe following files will be excluded:" "White"
    $excludeFiles | ForEach-Object { Write-Log "  $_" "Yellow" }
    exit 0
}

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

# Get settings from config or use defaults
$settings = @{
    Threads    = 16
    RetryCount = 5
    RetryWait  = 1
}

if ($config.ContainsKey('Settings')) {
    foreach ($line in $config['Settings']) {
        if ($line -match '^(\w+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            
            switch ($key) {
                'SourceDrive' { 
                    if (Test-Path -Path $value) {
                        $sourceDrive = $value
                    }
                    else {
                        Write-Log "Warning: Source drive $value not found, using default: $sourceDrive" "Yellow"
                    }
                }
                'Threads' { 
                    $threadCount = [int]$value
                    if ($threadCount -ge 1 -and $threadCount -le 128) {
                        $settings.Threads = $threadCount
                    }
                    else {
                        Write-Log "Warning: Thread count must be between 1 and 128, using default: $($settings.Threads)" "Yellow"
                    }
                }
                'RetryCount' { 
                    $retryCount = [int]$value
                    if ($retryCount -ge 0 -and $retryCount -le 100) {
                        $settings.RetryCount = $retryCount
                    }
                    else {
                        Write-Log "Warning: Retry count must be between 0 and 100, using default: $($settings.RetryCount)" "Yellow"
                    }
                }
                'RetryWait' {
                    $retryWait = [int]$value
                    if ($retryWait -ge 0 -and $retryWait -le 60) {
                        $settings.RetryWait = $retryWait
                    }
                    else {
                        Write-Log "Warning: Retry wait must be between 0 and 60 seconds, using default: $($settings.RetryWait)" "Yellow"
                    }
                }
                default {
                    Write-Log "Warning: Unknown setting '$key' ignored" "Yellow"
                }
            }
        }
    }
}


# Calculate total size and check space
$totalSize = 0
foreach ($dir in $backupDirs) {
    if (Test-Path -Path $dir) {
        $totalSize += Get-DirectorySize -path $dir
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
$totalDirs = $backupDirs.Count

# Backup Process
foreach ($dir in $backupDirs) {
    $currentDir++
    $progress = [math]::Round(($currentDir / $totalDirs) * 100, 2)
    
    $relativePath = $dir.Substring($sourceDrive.Length)
    $destPath = Join-Path -Path $destinationPath -ChildPath $relativePath

    if (Test-Path -Path $dir) {
        Write-Log "[$progress%] Processing: $dir" "Cyan"
        try {
            # Create parent directories
            New-Item -ItemType Directory -Path (Split-Path -Parent $destPath) -Force -ErrorAction SilentlyContinue | Out-Null
            
            # Build robocopy command with exclusions
            $robocopyArgs = @(
                $dir,
                $destPath,
                "/E", # Copy subdirectories, including empty ones
                "/XO", # Exclude older files
                "/XJ", # Exclude junction points
                "/R:$($settings.RetryCount)", # Number of retries
                "/W:$($settings.RetryWait)", # Wait time between retries
                "/NP", # No progress
                "/MT:$($settings.Threads)", # Use configured thread count
                "/Z", # Copy in restartable mode
                "/B", # Backup mode
                "/LOG+:backup_log.txt"
            ) + $excludeParams

            # Execute robocopy
            $result = & robocopy $robocopyArgs
            
            # Check robocopy exit code
            $exitCode = $LASTEXITCODE
            if ($exitCode -ge 8) {
                Write-Log "Warning: Some files in $dir may not have been copied (Exit code: $exitCode)" "Yellow"
            }
            else {
                Write-Log "Successfully copied $dir" "Green"
            }
        }
        catch {
            Write-Log "Error copying $dir : $_" "Red"
        }
    }
    else {
        Write-Log "Skipping $dir as it does not exist." "Yellow"
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
Settings:
  - Threads: $($settings.Threads)
  - Retry Count: $($settings.RetryCount)
  - Retry Wait: $($settings.RetryWait)
Excluded Directories: $(($excludeDirs | Where-Object { $_ }) -join ', ')
Excluded Files: $(($excludeFiles | Where-Object { $_ }) -join ', ')
"@
$summary | Out-File -FilePath (Join-Path -Path $destinationPath -ChildPath "backup_summary.txt")

Write-Log "Backup completed! Summary saved to backup_summary.txt" "Green"