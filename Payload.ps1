# Payload.ps1 - ScriptBlock payloads to run on remote machines
# Add different payloads as scriptblocks here

# Arduino CLI check payload
$Payload_VerifyArduinoCLI = {
    $path = Get-Command arduino-cli -ErrorAction SilentlyContinue
    if ($path) {
        [PSCustomObject]@{ Check = "Installed at: $($path.Source)" }
    } else {
        [PSCustomObject]@{ Check = "NOT INSTALLED" }
    }
}

$Payload_DeployArduinoCLI = {
    $chocoExe = "C:\ProgramData\chocolatey\bin\choco.exe"
    
    # 1. Check if Chocolatey exists
    if (-not (Test-Path $chocoExe)) {
        return [PSCustomObject]@{ Check = "FAILED: Chocolatey not found" }
    }

    try {
        # 2. Run the installation
        # -y: auto-confirm, --no-progress: cleaner logs for remote sessions
        & $chocoExe install arduino-cli -y --no-progress | Out-Null
        
        # 3. Verify the installation after the command
        $verify = Get-Command arduino-cli -ErrorAction SilentlyContinue
        if ($verify) {
            return [PSCustomObject]@{ Check = "SUCCESS: Installed at $($verify.Source)" }
        } else {
            return [PSCustomObject]@{ Check = "FAILED: Command finished but executable not found in PATH" }
        }
    } catch {
        return [PSCustomObject]@{ Check = "ERROR: $($_.Exception.Message)" }
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
        IP = (
            nslookup "$env:COMPUTERNAME.yorku.yorku.ca" 2>$null |
            Select-String '\d+\.\d+\.\d+\.\d+' |
            Select-Object -Last 1
        ).Matches[0].Value
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

# Verify PICO/RP2040 core installation
$Payload_VerifyPicoCore = {
    try {
        # First check if arduino-cli is available
        $arduinoCli = Get-Command arduino-cli -ErrorAction SilentlyContinue
        if (-not $arduinoCli) {
            return [PSCustomObject]@{ Check = "FAILED: arduino-cli not installed" }
        }

        # Get the core list
        $coreList = & arduino-cli core list 2>&1
        $coreListString = $coreList | Out-String

        if ($coreListString -match "rp2040:rp2040") {
            # Extract version if possible
            $versionMatch = $coreListString -match "rp2040:rp2040\s+(\S+)"
            $version = if ($Matches -and $Matches[1]) { $Matches[1] } else { "unknown" }
            return [PSCustomObject]@{ Check = "OK: RP2040 core installed (v$version)" }
        } else {
            return [PSCustomObject]@{ Check = "NOT INSTALLED: RP2040 core not found" }
        }
    } catch {
        return [PSCustomObject]@{ Check = "ERROR: $($_.Exception.Message)" }
    }
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


# Check Docker Desktop installation and version
$Payload_CheckDockerDesktop = {
    $dockerPath = "C:\Program Files\Docker\Docker Desktop.exe"
    
    if (Test-Path $dockerPath) {
        $file = Get-Item $dockerPath
        $version = $file.VersionInfo.ProductVersion
        
        # Try to get running Docker version if possible
        $dockerVersion = & docker --version 2>$null
        if ($dockerVersion) {
            $dockerVersion = $dockerVersion.Trim()
        } else {
            $dockerVersion = "File detected, docker CLI not in PATH"
        }
        
        [PSCustomObject]@{
            Check = "INSTALLED - File: v$version | CLI: $dockerVersion"
        }
    } else {
        [PSCustomObject]@{
            Check = "NOT INSTALLED"
        }
    }
}

# Deploy DIGT2201 VENV - EMBEDDED
$Payload_DeployDigt2201Venv = {
    # ----------------------------- EXACT NETWORK SCRIPT EMBEDDED -----------------------------
    $embeddedScript = @'
$VenvRoot = "C:\python-venvs"
$VenvName = "digt2201"
$VenvPath = Join-Path $VenvRoot $VenvName
$BasePython = "C:\Program Files\Python312\python.exe"
$PythonExe = "$VenvPath\Scripts\python.exe"

if (!(Test-Path $VenvRoot)) {
    New-Item -ItemType Directory -Path $VenvRoot -Force | Out-Null
}

if (!(Test-Path $PythonExe)) {
    "Creating virtual environment $VenvName using Python 3.12..."
    & $BasePython -m venv $VenvPath
}

if (!(Test-Path $PythonExe)) {
    "Virtual environment creation failed"
    exit 1
}

& $PythonExe -m pip install --upgrade pip

"Installing packages into $VenvName venv..."
& $PythonExe -m pip install numpy scipy scikit-learn matplotlib seaborn
& $PythonExe -m pip install tensorflow
& $PythonExe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

"✅ Virtual environment setup complete"
'@

    # Execute embedded script and capture result
    try {
        $output = Invoke-Expression $embeddedScript 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            [PSCustomObject]@{ 
                Check = "✅ SUCCESS: $($output[-3..-1] -join ' | ')" 
            }
        } else {
            [PSCustomObject]@{ 
                Check = "❌ FAILED(exit $exitCode): $($output | Where-Object { $_ -match 'failed|error' } | Select-Object -Last 1)" 
            }
        }
    }
    catch {
        [PSCustomObject]@{ 
            Check = "❌ EXCEPTION: $($_.Exception.Message)" 
        }
    }
}


# Deploy DIGT3131 VENV - EXACT embedded script
$Payload_DeployDigt3131Venv = {
    $embeddedScript = @'
$VenvRoot = "C:\python-venvs"
$VenvName = "digt3131"
$VenvPath = Join-Path $VenvRoot $VenvName
$PythonExe = "$VenvPath\Scripts\python.exe"

if (!(Test-Path $VenvRoot)) {
    New-Item -ItemType Directory -Path $VenvRoot -Force | Out-Null
}

if (!(Test-Path $PythonExe)) {
    "Creating virtual environment $VenvName..."
    python -m venv $VenvPath
}

if (!(Test-Path $PythonExe)) {
    "Virtual environment creation failed"
    exit 1
}

& $PythonExe -m pip install --upgrade pip

"Installing scientific & ML packages into $VenvName venv..."
& $PythonExe -m pip install numpy pandas scipy scikit-learn matplotlib seaborn plotly statsmodels
& $PythonExe -m pip install tensorflow keras
& $PythonExe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

"✅ Virtual environment digt3131 setup complete"
'@

    try {
        $output = Invoke-Expression $embeddedScript 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            [PSCustomObject]@{ Check = "✅ DIGT3131 SUCCESS: $($output[-3..-1] -join ' | ')" }
        } else {
            [PSCustomObject]@{ Check = "❌ DIGT3131 FAILED($exitCode): $($output[-1])" }
        }
    }
    catch {
        [PSCustomObject]@{ Check = "❌ DIGT3131 ERROR: $($_.Exception.Message)" }
    }
}

# Deploy DIGT3231 VENV - PyMOL Python
$Payload_DeployDigt3231Venv = {

    $embeddedScript = @'
$ErrorActionPreference = "Stop"

$VenvRoot  = "C:\python-venvs"
$VenvName  = "digt3231"
$VenvPath  = Join-Path $VenvRoot $VenvName
$BasePython = "C:\ProgramData\pymol\python.exe"
$PythonExe  = "$VenvPath\Scripts\python.exe"
$PipExe     = "$VenvPath\Scripts\pip.exe"

if (!(Test-Path $VenvRoot)) {
    New-Item -ItemType Directory -Path $VenvRoot -Force | Out-Null
}

if (!(Test-Path $PythonExe)) {
    Write-Output "Creating DIGT3231 venv using PyMOL Python..."
    & $BasePython -m venv $VenvPath
}

if (!(Test-Path $PythonExe)) {
    Write-Error "Virtual environment creation failed"
    exit 1
}

Write-Output "Upgrading pip tooling..."
& $PythonExe -m pip install --upgrade pip setuptools wheel

Write-Output "Installing core scientific packages..."
& $PipExe install numpy pandas scipy scikit-learn matplotlib seaborn pillow pytest requests rdkit statsmodels

Write-Output "Installing bioinformatics packages..."
& $PipExe install biopython biopandas pypdb networkx mordred

Write-Output "Installing PyMOL..."
& $PipExe install pymol-open-source

Write-Output "Installing TensorFlow (CPU)..."
& $PipExe install tensorflow-cpu

Write-Output "Installing PyTorch (CPU)..."
& $PipExe install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

Write-Output "DIGT3231 venv deployment complete"
exit 0
'@

    try {
        # Create temp script file
        $tempScript = Join-Path $env:TEMP "deploy_digt3231_venv.ps1"
        Set-Content -Path $tempScript -Value $embeddedScript -Encoding UTF8 -Force

        # Execute safely
        $output = & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $tempScript 2>&1

        $exitCode = $LASTEXITCODE

        # Cleanup
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

        if ($exitCode -eq 0) {
            [PSCustomObject]@{
                Check = "✅ DIGT3231 SUCCESS: $((($output | Select-Object -Last 2) -join ' | '))"
            }
        }
        else {
            [PSCustomObject]@{
                Check = "❌ DIGT3231 FAILED ($exitCode): $($output | Select-Object -Last 1)"
            }
        }
    }
    catch {
        [PSCustomObject]@{
            Check = "❌ DIGT3231 ERROR: $($_.Exception.Message)"
        }
    }
}

# Force Group Policy update
$Payload_GPUpdate = {
    try {
        $output = & gpupdate /force 2>&1
        $success = $output | Select-String -Pattern "successfully" -Quiet
        
        if ($success) {
            [PSCustomObject]@{ Check = "GPO UPDATE SUCCESS" }
        } else {
            [PSCustomObject]@{ Check = "GPO UPDATE COMPLETED: $($output[-1])" }
        }
    }
    catch {
        [PSCustomObject]@{ Check = "FAILED: $($_.Exception.Message)" }
    }
}

# Reboot the computer
$Payload_RebootComputer = {
    try {
        # Schedule reboot with delay to allow response to be sent back
        & shutdown.exe /r /t 10 /f /c "Remote reboot initiated by admin script" 2>&1 | Out-Null
        
        [PSCustomObject]@{ Check = "REBOOTING in 10 seconds..." }
    }
    catch {
        [PSCustomObject]@{ Check = "FAILED: $($_.Exception.Message)" }
    }
}

# Download and install LibreOffice 26.2.0 (Win x86-64) [web:24]
$Payload_InstallLibreOffice = {
    $url = "https://download.documentfoundation.org/libreoffice/stable/26.2.0/win/x86_64/LibreOffice_26.2.0_Win_x86-64.msi"
    $msiPath = Join-Path $env:TEMP "LibreOffice_26.2.0_Win_x86-64.msi"
    $minSizeBytes = 300 * 1024 * 1024   # ~300 MB - full MSI is ~355 MB [web:32][web:33][web:36]

    # Download [web:1][web:15]
    [PSCustomObject]@{ Check = "Downloading LibreOffice 26.2.0..." } | Out-Null

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing -UserAgent $ua -MaximumRedirection 10

        if (-not (Test-Path $msiPath)) {
            return [PSCustomObject]@{ Check = "FAILED: Download did not create file" }
        }

        $fileSize = (Get-Item $msiPath).Length
        if ($fileSize -lt $minSizeBytes) {
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            return [PSCustomObject]@{ Check = "FAILED: Download incomplete or corrupt (size $([math]::Round($fileSize/1MB,2)) MB, need ~355 MB)" }
        }

        # Silent install [web:35]
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "msiexec.exe"
        $psi.Arguments = "/i `"$msiPath`" /quiet /norestart RebootYesNo=No"  # Added RebootYesNo=No for reliability [web:35]
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit(600000)  # wait up to 10 minutes

        $exitCode = $p.ExitCode
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

        if ($exitCode -eq 0) {
            return [PSCustomObject]@{ Check = "SUCCESS: LibreOffice 26.2.0 installed" }
        } elseif ($exitCode -eq 3010) {
            return [PSCustomObject]@{ Check = "SUCCESS: Installed; reboot required" }
        } elseif ($exitCode -eq 1620) {
            return [PSCustomObject]@{ Check = "FAILED (1620): Installer could not open package - often corrupt/incomplete download or access denied" }
        } else {
            return [PSCustomObject]@{ Check = "FAILED: Install exit code $exitCode" }
        }
    }
    catch {
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ Check = "FAILED: $($_.Exception.Message)" }
    }
}

