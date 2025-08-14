# Path to registry key and value
$RegPath = "HKLM:\SOFTWARE\Company\Autopilot"
$ValueName = "MSOffice"

# Check if registry value exists and is set to 1
$Completed = $false
if (Test-Path $RegPath) {
    $prop = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue
    if ($prop.$ValueName -eq 1) {
        $Completed = $true
    }
}

if (-not $Completed) {
    # Download the Office removal script
    iwr https://raw.githubusercontent.com/Admonstrator/msoffice-removal-tool/main/msoffice-removal-tool.ps1 -OutFile msoffice-removal-tool.ps1

    # Run the Office removal script and capture exit code
    $process = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File .\msoffice-removal-tool.ps1" -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        # Create the registry key if it doesn't exist
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
} else {
    exit
}
