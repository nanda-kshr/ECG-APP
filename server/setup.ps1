# ECG Database Setup Script
# Run this to set up the database with correct structure

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ECG Task Assignment System - Database Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find MySQL executable
Write-Host "Step 1: Locating MySQL..." -ForegroundColor Yellow

$mysqlPaths = @(
    "C:\xampp\mysql\bin\mysql.exe",
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
    "C:\Program Files\MySQL\MySQL Server 5.7\bin\mysql.exe",
    "C:\wamp64\bin\mysql\mysql8.0.31\bin\mysql.exe",
    "C:\laragon\bin\mysql\mysql-8.0.30-winx64\bin\mysql.exe"
)

$mysqlPath = $null
foreach ($path in $mysqlPaths) {
    if (Test-Path $path) {
        $mysqlPath = $path
        Write-Host "✓ Found MySQL at: $path" -ForegroundColor Green
        break
    }
}

if (-not $mysqlPath) {
    Write-Host "✗ MySQL not found in common locations." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please enter the full path to mysql.exe:" -ForegroundColor Yellow
    $mysqlPath = Read-Host "Path"
    
    if (-not (Test-Path $mysqlPath)) {
        Write-Host "✗ Invalid path. Exiting." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Confirm before proceeding
Write-Host "⚠️  WARNING: This will DROP and RECREATE all tables!" -ForegroundColor Red
Write-Host "   - All existing data in users, reports, tasks will be DELETED" -ForegroundColor Red
Write-Host "   - Fresh test users will be created" -ForegroundColor Yellow
Write-Host "   - Password for all test users: password123" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Are you sure you want to continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 2: Running fresh_setup.sql..." -ForegroundColor Yellow
Write-Host ""

# Run the SQL script
$sqlFile = Join-Path $PSScriptRoot "fresh_setup.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "✗ fresh_setup.sql not found at: $sqlFile" -ForegroundColor Red
    exit 1
}

# Execute MySQL command
$arguments = @(
    "-u", "root",
    "-p",
    "ecg_db"
)

Write-Host "Running: $mysqlPath $arguments < $sqlFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Please enter MySQL root password when prompted..." -ForegroundColor Cyan
Write-Host ""

Get-Content $sqlFile | & $mysqlPath $arguments

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ DATABASE SETUP SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Test Credentials:" -ForegroundColor Cyan
    Write-Host "  Admin:      admin@ecg.com / password123" -ForegroundColor White
    Write-Host "  Doctor 1:   doctor1@ecg.com / password123" -ForegroundColor White
    Write-Host "  Doctor 2:   doctor2@ecg.com / password123" -ForegroundColor White
    Write-Host "  Technician: tech1@ecg.com / password123" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Create uploads directory:" -ForegroundColor White
    Write-Host "     New-Item -ItemType Directory -Path 'server\uploads\ecg_images' -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Test login from Flutter app" -ForegroundColor White
    Write-Host ""
    Write-Host "  3. Test technician upload workflow" -ForegroundColor White
    Write-Host ""
    
} else {
    Write-Host ""
    Write-Host "✗ Setup failed. Please check the error messages above." -ForegroundColor Red
    exit 1
}

# Create uploads directory
Write-Host "Step 3: Creating uploads directory..." -ForegroundColor Yellow
$uploadsPath = Join-Path (Split-Path $PSScriptRoot) "server\uploads\ecg_images"

try {
    New-Item -ItemType Directory -Path $uploadsPath -Force | Out-Null
    Write-Host "✓ Uploads directory created at: $uploadsPath" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not create uploads directory: $_" -ForegroundColor Yellow
    Write-Host "  You may need to create it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Setup complete! 🎉" -ForegroundColor Green
