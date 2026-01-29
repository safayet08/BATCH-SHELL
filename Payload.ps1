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

# Install Chocolatey
$Payload_InstallChocolatey = {
    # Check if Chocolatey is already installed
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoPath) {
        $version = & choco --version 2>$null
        [PSCustomObject]@{ Check = "Already installed: v$version" }
    } else {
        try {
            # Set execution policy and install Chocolatey
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Refresh environment and verify
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $version = & choco --version 2>$null
            if ($version) {
                [PSCustomObject]@{ Check = "SUCCESS: Installed v$version" }
            } else {
                [PSCustomObject]@{ Check = "INSTALLED (restart shell to verify)" }
            }
        } catch {
            [PSCustomObject]@{ Check = "FAILED: $($_.Exception.Message)" }
        }
    }
}

# Check if Chocolatey is installed (without installing)
$Payload_CheckChocolatey = {
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoPath) {
        $version = & choco --version 2>$null
        [PSCustomObject]@{ Check = "Installed: v$version at $($chocoPath.Source)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Check if Faronics Insight Student is installed
$Payload_CheckFaronicsInsight = {
    $insightPath = "C:\Program Files\Faronics\Insight Student\FIStudentUI.exe"
    if (Test-Path $insightPath) {
        $file = Get-Item $insightPath
        [PSCustomObject]@{ Check = "INSTALLED - Version: $($file.VersionInfo.FileVersion)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Check if IntelliJ IDEA is installed
$Payload_CheckIntelliJ = {
    $ideaPath = "C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2025.2.5\bin\idea64.exe"
    if (Test-Path $ideaPath) {
        $file = Get-Item $ideaPath
        [PSCustomObject]@{ Check = "INSTALLED - Version: $($file.VersionInfo.ProductVersion)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Check if PyCharm is installed
$Payload_CheckPyCharm = {
    $pycharmPath = "C:\Program Files\JetBrains\PyCharm Community Edition 2025.2.5\bin\pycharm64.exe"
    if (Test-Path $pycharmPath) {
        $file = Get-Item $pycharmPath
        [PSCustomObject]@{ Check = "INSTALLED - Version: $($file.VersionInfo.ProductVersion)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Check if Arduino IDE is installed
$Payload_CheckArduinoIDE = {
    $arduinoPath = "C:\Program Files\arduino-ide\Arduino IDE.exe"
    if (Test-Path $arduinoPath) {
        $file = Get-Item $arduinoPath
        [PSCustomObject]@{ Check = "INSTALLED - Version: $($file.VersionInfo.ProductVersion)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

# Check Labtest/Exam system files timestamps (GPO sync verification)
$Payload_CheckLabtestFiles = {
    $basePath = "C:\ProgramData\LabtestLogs"
    $mitmPath = "$basePath\mitmproxy"

    $filesToCheck = @(
        "$basePath\proxy-logic.py",
        "$basePath\proxy-toggler.ps1"
    )

    # Add mitmproxy directory files if it exists
    if (Test-Path $mitmPath) {
        $filesToCheck += Get-ChildItem -Path $mitmPath -File | ForEach-Object { $_.FullName }
    }

    $results = foreach ($filePath in $filesToCheck) {
        $fileName = Split-Path $filePath -Leaf
        if (Test-Path $filePath) {
            $file = Get-Item $filePath
            [PSCustomObject]@{
                File          = $fileName
                LastWriteTime = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                Size          = $file.Length
            }
        }
        else {
            [PSCustomObject]@{
                File          = $fileName
                LastWriteTime = "MISSING"
                Size          = 0
            }
        }
    }

    # Compact single-line summary: File:timestamp(size); File:timestamp(size)
    $summaryLines = $results | ForEach-Object { 
        "$($_.File):$($_.LastWriteTime)($($_.Size)B)"
    }
    $summary = ($summaryLines -join '; ') -replace 'MISSING\(0B\)', 'MISSING'

    [PSCustomObject]@{
        Check = $summary
    }
}
