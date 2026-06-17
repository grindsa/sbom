[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the target date (e.g. 31.12.2025 or 2025-12-31).")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetDate
)

# 1. Check for administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator (elevated privileges)!"
    Exit
}

# 2. Validate and format date
try {
    $parsedDate = [DateTime]::Parse($TargetDate)
    # Certutil expects the date in the system's regional format (e.g. dd.MM.yyyy)
    $formattedDate = $parsedDate.ToString("d")
    Write-Host "Processing entries older than: $formattedDate" -ForegroundColor Cyan
} catch {
    Write-Error "Invalid date format entered. Please use a standard format (e.g. DD.MM.YYYY)."
    Exit
}

# 3. Loop for deleting expired certificates (handles timeouts)
Write-Host "`n[1/3] Deleting expired certificates (Cert)..." -ForegroundColor Yellow
do {
    # Capture certutil output
    $output = certutil -deleterow $formattedDate Cert 2>&1
    $lastExitCode = $LASTEXITCODE

    # Check timeout error code (code: -939523027 / 0xc7fe002d)
    $isTimeout = ($lastExitCode -eq -939523027) -or ($output -match "0xc7fe002d")

    if ($isTimeout) {
        Write-Host "Batch limit/timeout reached. Starting next run..." -ForegroundColor Gray
    }
} while ($isTimeout)
Write-Host "Certificate cleanup completed." -ForegroundColor Green

# 4. Loop for deleting old certificate requests (handles timeouts)
Write-Host "`n[2/3] Deleting old certificate requests (Request)..." -ForegroundColor Yellow
do {
    $output = certutil -deleterow $formattedDate Request 2>&1
    $lastExitCode = $LASTEXITCODE
    $isTimeout = ($lastExitCode -eq -939523027) -or ($output -match "0xc7fe002d")

    if ($isTimeout) {
        Write-Host "Batch limit/timeout reached. Starting next run..." -ForegroundColor Gray
    }
} while ($isTimeout)
Write-Host "Request cleanup completed." -ForegroundColor Green

# 5. Compress database offline
Write-Host "`n[3/3] Starting database compression..." -ForegroundColor Yellow

# Stop CA service
Write-Host "Stopping certificate service (CertSvc)..." -ForegroundColor Gray
Stop-Service -Name "CertSvc" -Force

# Read EDB database path from the registry
try {
    $dbDirectory = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration" -Name "DBDirectory"
    $caName = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration" -Name "Active"
    $dbPath = Join-Path $dbDirectory "$caName.edb"

    if (Test-Path $dbPath) {
        Write-Host "Compressing database at: $dbPath" -ForegroundColor Gray
        # Run esentutl
        esentutl /d `"$dbPath`"
    } else {
        Write-Warning "Database file was not found at path $dbPath."
    }
} catch {
    Write-Error "Error determining database path: $_"
}

# Restart CA service
Write-Host "Starting certificate service (CertSvc) again..." -ForegroundColor Gray
Start-Service -Name "CertSvc"

Write-Host "`nCleanup and compression completed successfully!" -ForegroundColor Green