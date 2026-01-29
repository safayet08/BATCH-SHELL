# Payload.ps1 - ScriptBlock payloads to run on remote machines
# Add different payloads as scriptblocks here

# Arduino CLI check payload
$Payload_ArduinoCLI = {
    $path = Get-Command arduino-cli -ErrorAction SilentlyContinue
    if ($path) {
        [PSCustomObject]@{ Check = "Installed at: $($path.Source)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Example: Check if a specific software is installed
$Payload_CheckSoftware = {
    param($SoftwareName)
    $path = Get-Command $SoftwareName -ErrorAction SilentlyContinue
    if ($path) {
        [PSCustomObject]@{ Check = "Installed at: $($path.Source)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Example: Get system info
$Payload_SystemInfo = {
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        OS = (Get-CimInstance Win32_OperatingSystem).Caption
        RAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        LastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    }
}

# Example: Check disk space
$Payload_DiskSpace = {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [PSCustomObject]@{
            Drive = $_.DeviceID
            SizeGB = [math]::Round($_.Size / 1GB, 2)
            FreeGB = [math]::Round($_.FreeSpace / 1GB, 2)
            PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
        }
    }
}

# Example: List installed programs
$Payload_InstalledPrograms = {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher |
        Sort-Object DisplayName
}
