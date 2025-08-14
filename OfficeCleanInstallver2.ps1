# Path to registry key and value
$RegPath = "HKLM:\SOFTWARE\Company\Autopilot"
$ValueName = "MSOffice"
$ScriptPath = Join-Path -Path $env:TEMP -ChildPath "msoffice-removal-tool.ps1"

# Check if registry value exists and is set to 1
$Completed = $false
if (Test-Path $RegPath) {
    $prop = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue
    if ($prop -and $prop.$ValueName -eq 1) {
        $Completed = $true
    }
}

if (-not $Completed) {

    # Download the Office removal script
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Admonstrator/msoffice-removal-tool/main/msoffice-removal-tool.ps1" `
            -OutFile $ScriptPath -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to download the Office removal script: $_"
        exit 1
    }

    # Run the Office removal script and capture exit code
    try {
        $process = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait -PassThru
        if ($process -and $process.ExitCode -eq 0) {
            # Ensure the registry key exists
            if (-not (Test-Path $RegPath)) {
                New-Item -Path $RegPath -Force | Out-Null
            }
            # Set DWORD value to 1 to mark completion
            New-ItemProperty -Path $RegPath -Name $ValueName -Value 1 -PropertyType DWord -Force | Out-Null
            Write-Host "Office removal completed successfully. Registry key set."
        }
        else {
            Write-Host "Office removal script failed. Registry key not set."
        }
    }
    catch {
        Write-Host "Failed to execute the Office removal script: $_"
        exit 1
    }
} else {
    exit
}
