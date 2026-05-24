# OBD-Droid Flutter — Setup Script
# Ruleaza acest script o singura data pentru a instala Flutter si dependintele.
#
# Folosire:
#   1. Click dreapta pe acest fisier → "Run with PowerShell"
#   sau
#   2. In PowerShell: .\setup.ps1
#
# Daca primesti eroare de execution policy:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  OBD-Droid Flutter — Setup automat" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. Verifica Flutter ----------
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutterCmd) {
    Write-Host "[1/4] Flutter nu este instalat." -ForegroundColor Yellow

    if (-not (Test-Path "C:\flutter\bin\flutter.bat")) {
        Write-Host "      Descarcam Flutter SDK (~1 GB)..." -ForegroundColor Yellow
        $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.3-stable.zip"
        $zip = "$env:TEMP\flutter_sdk.zip"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Write-Host "      Extragem in C:\flutter (~5 minute)..." -ForegroundColor Yellow
        Expand-Archive -Path $zip -DestinationPath "C:\" -Force
        Remove-Item $zip -Force
    }

    Write-Host "      Adaugam Flutter in PATH..." -ForegroundColor Yellow
    $env:Path = "$env:Path;C:\flutter\bin"
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path, "User")
    Write-Host "      Flutter instalat la C:\flutter" -ForegroundColor Green
} else {
    Write-Host "[1/4] Flutter detectat: $($flutterCmd.Source)" -ForegroundColor Green
}

# ---------- 2. Doctor ----------
Write-Host ""
Write-Host "[2/4] Verificam Flutter doctor..." -ForegroundColor Cyan
& flutter doctor

# ---------- 3. Pub get ----------
Write-Host ""
Write-Host "[3/4] Descarcam dependintele Dart..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
& flutter pub get
Pop-Location

# ---------- 4. Devices ----------
Write-Host ""
Write-Host "[4/4] Dispozitive conectate:" -ForegroundColor Cyan
& flutter devices

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  Setup complet!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pentru a rula aplicatia pe Lenovo Tab M11:" -ForegroundColor White
Write-Host "  1. Conecteaza tableta cu USB-C"
Write-Host "  2. Activeaza USB Debugging in Setari -> Optiuni dezvoltator"
Write-Host "  3. Ruleaza:  flutter run"
Write-Host ""
