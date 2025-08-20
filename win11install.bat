@echo off
setlocal enabledelayedexpansion
REM ========================================================
REM Windows 10/11 Logging and Installation Script
REM With Network Check & Admin Elevation
REM ========================================================

:: -----------------------------------
:: Self-elevate batch file to run as Administrator
:: -----------------------------------
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

REM ------------------------------
REM Test network paths before proceeding
REM ------------------------------
set "NETWORK_PATHS=\\DESKTOP-VMISJCM\fileshare1\inplacelogs \\DESKTOP-VMISJCM\fileshare1\newdevicelogs"
echo Testing network connectivity...
set "ERRORFLAG=0"

for %%P in (%NETWORK_PATHS%) do (
    if not exist "%%P\" (
        echo ERROR: Network path %%P is not available!
        set "ERRORFLAG=1"
    ) else (
        echo Network path %%P is available.
    )
)

if "!ERRORFLAG!"=="1" (
    echo One or more network paths are unavailable. Exiting script.
    pause
    exit /b
)

echo All network paths are available. Continuing...
echo.

REM ------------------------------
REM User prompt: In-Place Upgrade or New Device
REM ------------------------------
:ASKDEVICE
echo.
echo Is this an In-Place Upgrade or a New Device setup?
echo 1. In-Place Upgrade
echo 2. New Device
set /p DEVICECHOICE=Enter 1 or 2:

if "%DEVICECHOICE%"=="1" (
    set "DEVICETYPE=In-Place Upgrade"
) else if "%DEVICECHOICE%"=="2" (
    set "DEVICETYPE=New Device"
) else (
    echo Invalid choice. Please enter 1 or 2.
    goto ASKDEVICE
)

echo You selected: %DEVICETYPE%
echo.

REM ------------------------------
REM Set log folder based on device type
REM ------------------------------
if /i "%DEVICETYPE%"=="In-Place Upgrade" (
    set "LOGFOLDER=\\DESKTOP-VMISJCM\fileshare1\inplacelogs"
) else if /i "%DEVICETYPE%"=="New Device" (
    set "LOGFOLDER=\\DESKTOP-VMISJCM\fileshare1\newdevicelogs"
)

if not exist "%LOGFOLDER%" mkdir "%LOGFOLDER%"

REM ------------------------------
REM Build log file name (safe date format)
REM ------------------------------
set "HOSTNAME=%COMPUTERNAME%"
set "USERNAME=%USERNAME%"

for /f "tokens=1-3 delims=/- " %%a in ("%date%") do (
    set YYYY=%%c
    set MM=%%a
    set DD=%%b
)

for /f "tokens=1-3 delims=:." %%a in ("%time%") do (
    set HH=%%a
    set MN=%%b
    set SS=%%c
)

if %HH% LSS 10 set HH=0%HH%
set "LOGDATE=%MM%-%DD%-%YYYY%_%HH%%MN%%SS%"
set "LOGFILE=%LOGFOLDER%\%HOSTNAME%_%USERNAME%_%LOGDATE%.txt"

REM ------------------------------
REM Start logging
REM ------------------------------
echo Start time: %LOGDATE%
echo Logging system info for %HOSTNAME% >> "%LOGFILE%"
echo Device type: %DEVICETYPE% >> "%LOGFILE%"
echo User: %USERNAME% >> "%LOGFILE%"
echo Date and Time: %LOGDATE% >> "%LOGFILE%"

systeminfo | findstr /B /C:"OS Name" /C:"OS Version" >> "%LOGFILE%"
echo Architecture: %PROCESSOR_ARCHITECTURE% >> "%LOGFILE%"

for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /R "IPv4 Address"') do echo IP Address: %%i >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM ------------------------------
REM List mapped network drives
REM ------------------------------
echo === Mapped Network Drives === >> "%LOGFILE%"

:: Get logged-in user's SID
for /f "skip=1 tokens=2" %%S in ('whoami /user /fo list ^| findstr /R "^S-"') do set "SID=%%S"

:: Persistent drives from registry
for /f "tokens=3" %%D in ('reg query "HKU\!SID!\Network" 2^>nul') do (
    for /f "tokens=3*" %%R in ('reg query "HKU\!SID!\Network\%%D" /v RemotePath 2^>nul ^| findstr /I "RemotePath"') do (
        echo %%D -> %%R >> "%LOGFILE%"
    )
)

:: Session-only drives using PowerShell
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 4} | ForEach-Object { $_.DeviceID + ' -> ' + $_.ProviderName }"') do (
    echo %%D >> "%LOGFILE%"
)

echo. >> "%LOGFILE%"

REM ------------------------------
REM List installed applications
REM ------------------------------
echo === Installed Applications (Classic/Win32) === >> "%LOGFILE%"
for /f "tokens=*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2^>nul') do (
    for /f "tokens=2*" %%B in ("%%A") do echo %%C >> "%LOGFILE%"
)
for /f "tokens=*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2^>nul') do (
    for /f "tokens=2*" %%B in ("%%A") do echo %%C >> "%LOGFILE%"
)
echo. >> "%LOGFILE%"

echo === Microsoft Store Apps === >> "%LOGFILE%"
powershell -NoProfile -Command "Get-AppxPackage | Select Name, Version | Format-Table -AutoSize" >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"

REM ------------------------------
REM Conditional continuation
REM ------------------------------
if /i "%DEVICETYPE%"=="In-Place Upgrade" (
    echo ==============================================
    echo WARNING: You are about to wipe and upgrade to
    echo Windows 11 24H2 Enterprise LTSC
    echo ==============================================
    choice /M "Do you want to continue?"
    if errorlevel 2 (
        echo User cancelled the installation. Exiting.
        pause
        exit /b
    ) else (
        echo User confirmed. Starting Windows 11 installation...
        REM ===================================
        REM ADD YOUR WINDOWS 11 INSTALLATION COMMANDS BELOW
        REM Example:
        REM start C:\fileshare1\win11install.bat
        REM ping 8.8.8.8 -t REM <-- avoid infinite ping if not needed
        REM ===================================
    )
) else if /i "%DEVICETYPE%"=="New Device" (
    echo Log file created, proceed with new device setup. You may close this window.
    pause
    exit /b
)
