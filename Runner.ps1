# Runner.ps1 - Main script to execute payloads on target locations
# Usage: .\Runner.ps1 -TargetRooms "MKH4000","MKH4005" -PayloadName "VerifyArduinoCLI"
# Usage: .\Runner.ps1 -TargetComputers "MKH-4025-04","MKH-4010-01" -PayloadName "SystemInfo"

param(
    [Parameter(Mandatory=$false)]
    [string[]]$TargetRooms,
    
    [Parameter(Mandatory=$false)]
    [string[]]$TargetComputers,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("VerifyArduinoCLI", "SystemInfo", "DiskSpace", "InstalledPrograms", "DeployArduinoCLI", "VerifyPicoCore", "InstallChocolatey", "CheckChocolatey", "CheckFaronicsInsight", "CheckIntelliJ", "CheckPyCharm", "CheckArduinoIDE", "CheckLabtestFiles")]
    [string]$PayloadName = "VerifyArduinoCLI",
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = "yorku.yorku.ca"
)

# Get script directory for relative paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load locations and payloads
. "$ScriptDir\Locations.ps1"
. "$ScriptDir\Payload.ps1"

# Select the payload based on parameter
$Payload = switch ($PayloadName) {
    "SystemInfo"           { $Payload_SystemInfo }
    "DiskSpace"            { $Payload_DiskSpace }
    "InstalledPrograms"    { $Payload_InstalledPrograms }
    "VerifyArduinoCLI"     { $Payload_VerifyArduinoCLI }
    "DeployArduinoCLI"     { $Payload_DeployArduinoCLI }
    "VerifyPicoCore"       { $Payload_VerifyPicoCore }
    "InstallChocolatey"    { $Payload_InstallChocolatey }
    "CheckChocolatey"      { $Payload_CheckChocolatey }
    "CheckFaronicsInsight" { $Payload_CheckFaronicsInsight }
    "CheckIntelliJ"        { $Payload_CheckIntelliJ }
    "CheckPyCharm"         { $Payload_CheckPyCharm }
    "CheckArduinoIDE"      { $Payload_CheckArduinoIDE }
    "CheckLabtestFiles"    { $Payload_CheckLabtestFiles }
    default                { $Payload_VerifyArduinoCLI }
}

# Determine target mode and get computers
if ($TargetComputers -and $TargetComputers.Count -gt 0) {
    # Mode: Specific computers by LabID
    $TargetMode = "Computers"
    $ComputerHashtable = Get-SpecificComputers -ComputerIds $TargetComputers
    $TargetDisplay = $TargetComputers -join ', '
} elseif ($TargetRooms -and $TargetRooms.Count -gt 0) {
    # Mode: All computers in specified rooms
    $TargetMode = "Rooms"
    $ComputerHashtable = Get-RoomComputers -Rooms $TargetRooms -Domain $Domain
    $TargetDisplay = $TargetRooms -join ', '
} else {
    # Default: All rooms
    $TargetMode = "Rooms"
    $TargetRooms = @("MKH4000", "MKH4005", "MKH4010", "MKH4015", "MKH4025")
    $ComputerHashtable = Get-RoomComputers -Rooms $TargetRooms -Domain $Domain
    $TargetDisplay = $TargetRooms -join ', '
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remote Execution Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target Mode: $TargetMode" -ForegroundColor Yellow
Write-Host "Targets: $TargetDisplay" -ForegroundColor Yellow
Write-Host "Payload: $PayloadName" -ForegroundColor Yellow
Write-Host "Total Computers: $($ComputerHashtable.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Build the FQDN list (filter out empty values)
$computerList = $ComputerHashtable.Values | 
    Where-Object { $_ -ne "" } | 
    ForEach-Object { "$_.$Domain" }

Write-Host "`nConnecting to $($computerList.Count) computers..." -ForegroundColor Cyan

# Get credentials
$myCred = Get-Credential -Message "Enter Admin Credentials"
if ($null -eq $myCred) {
    Write-Host "Credentials not provided. Exiting." -ForegroundColor Red
    return
}

# Execute the payload on all target computers
$results = Invoke-Command -ComputerName $computerList -ScriptBlock $Payload -Credential $myCred -ErrorAction SilentlyContinue

# Create the report mapping Lab IDs back to Hostnames
$report = foreach ($entry in $ComputerHashtable.GetEnumerator()) {
    $labId = $entry.Key
    $hostname = "$($entry.Value).$Domain"
    
    # Match the remote result to the local hashtable entry
    $match = $results | Where-Object { $_.PSComputerName -eq $hostname }
    
    # Build report entry based on payload type
    $status = if ($match) {
        if ($match.Check) { $match.Check }
        else { $match | Select-Object -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName }
    } else {
        "OFFLINE / UNREACHABLE"
    }
    
    [PSCustomObject]@{
        LabID    = $labId
        Hostname = $entry.Value
        Status   = $status
    }
}

# Output the report
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Results:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$report | Sort-Object LabID | Format-Table -AutoSize

# Summary
$online = ($report | Where-Object { $_.Status -ne "OFFLINE / UNREACHABLE" }).Count
$offline = ($report | Where-Object { $_.Status -eq "OFFLINE / UNREACHABLE" }).Count

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Online/Responded: $online" -ForegroundColor Green
Write-Host "  Offline/Unreachable: $offline" -ForegroundColor Red
