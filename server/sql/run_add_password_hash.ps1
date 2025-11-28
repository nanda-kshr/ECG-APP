<#
PowerShell helper to backup the DB and run `add_password_hash.sql`.
Usage: run with PowerShell from repo root (where this script lives in server/sql/)

This script expects `mysqldump` and `mysql` to be in PATH (e.g. from XAMPP or MySQL client install).
It will prompt for DB connection details and create a timestamped SQL dump before applying the ALTER.
#>

param()

function Read-PlainPassword($prompt = "DB password") {
    $sec = Read-Host -Prompt $prompt -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

Write-Host "This will BACK UP the database and then run add_password_hash.sql against it.`n"

$mysqlExe = Read-Host "Path to mysql executable (or press Enter to use 'mysql')"
if ([string]::IsNullOrWhiteSpace($mysqlExe)) { $mysqlExe = 'mysql' }
$mysqldumpExe = Read-Host "Path to mysqldump executable (or press Enter to use 'mysqldump')"
if ([string]::IsNullOrWhiteSpace($mysqldumpExe)) { $mysqldumpExe = 'mysqldump' }
$dbHost = Read-Host "DB host (default: localhost)"
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = 'localhost' }
$dbName = Read-Host "Database name (default: ecg_app_db)"
if ([string]::IsNullOrWhiteSpace($dbName)) { $dbName = 'ecg_app_db' }
$dbUser = Read-Host "DB user (default: root)"
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = 'root' }
$dbPass = Read-PlainPassword "DB password (input hidden)"

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sqlFile = Join-Path $scriptDir 'add_password_hash.sql'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dumpFile = Join-Path $scriptDir "backup_${dbName}_$timestamp.sql"

Write-Host "Backing up database '$dbName' to: $dumpFile"
$dumpCmd = "$mysqldumpExe -h $dbHost -u $dbUser -p`"$dbPass`" $dbName > `"$dumpFile`""
# Use cmd /c to allow > redirection
cmd /c $dumpCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "mysqldump failed (exit code $LASTEXITCODE). Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "Backup completed." -ForegroundColor Green

# Confirm
$ok = Read-Host "Proceed to run ALTER (apply $sqlFile) on $dbName? Type YES to continue"
if ($ok -ne 'YES') {
    Write-Host "Aborted by user. No changes made." -ForegroundColor Yellow
    exit 0
}

# Execute SQL file
$applyCmd = "$mysqlExe -h $dbHost -u $dbUser -p`"$dbPass`" $dbName < `"$sqlFile`""
cmd /c $applyCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "Applying SQL failed (exit code $LASTEXITCODE). Check your mysql client and credentials." -ForegroundColor Red
    exit 1
}
Write-Host "SQL applied successfully." -ForegroundColor Green
Write-Host "You can now run the migration script: php ..\scripts\migrate_passwords.php --dry" -ForegroundColor Cyan
