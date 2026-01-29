# Runner.ps1 - Main script to execute payloads on target locations
# Usage: 
#   .\Runner.ps1 -TargetRooms "MKH4000","MKH4005" -PayloadName "ArduinoCLI"
#   .\Runner.ps1 -Target "MKH-4010-06" -PayloadName "DiskSpace"
#   .\Runner.ps1 -Target "MKH-4010-06","MKH-4010-07" -PayloadName "SystemInfo"

param(
    [Parameter(Mandatory=$false)]
    [string[]]$TargetRooms,
    
    [Parameter(Mandatory=$false)]
    [string[]]$Target,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("ArduinoCLI", "SystemInfo", "DiskSpace", "InstalledPrograms", "InstallChocolatey", "CheckChocolatey", "CheckFaronicsInsight", "CheckIntelliJ", "CheckPyCharm", "CheckArduinoIDE", "CheckLabtestFiles", "CheckDockerDesktop")]
    [string]$PayloadName = "ArduinoCLI",
    
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
    "ArduinoCLI"           { $Payload_ArduinoCLI }
    "SystemInfo"           { $Payload_SystemInfo }
    "DiskSpace"            { $Payload_DiskSpace }
    "InstalledPrograms"    { $Payload_InstalledPrograms }
    "InstallChocolatey"    { $Payload_InstallChocolatey }
    "CheckChocolatey"      { $Payload_CheckChocolatey }
    "CheckFaronicsInsight" { $Payload_CheckFaronicsInsight }
    "CheckIntelliJ"        { $Payload_CheckIntelliJ }
    "CheckPyCharm"         { $Payload_CheckPyCharm }
    "CheckArduinoIDE"      { $Payload_CheckArduinoIDE }
    "CheckLabtestFiles"    { $Payload_CheckLabtestFiles }
    "CheckDockerDesktop"   { $Payload_CheckDockerDesktop }
    default                { $Payload_ArduinoCLI }
}

# Build the combined list of all locations for lookups
$AllRooms = Get-RoomComputers -Rooms @("MKH4000", "MKH4005", "MKH4010", "MKH4015", "MKH4025")

# Determine target computers based on parameters
$TargetComputers = @{}

if ($Target) {
    # Target specific computers by Lab ID (e.g., "MKH-4010-06") or hostname
    foreach ($t in $Target) {
        if ($AllRooms.ContainsKey($t)) {
            # It's a Lab ID
            $TargetComputers[$t] = $AllRooms[$t]
        } elseif ($AllRooms.Values -contains $t) {
            # It's a hostname - find the Lab ID
            $labId = ($AllRooms.GetEnumerator() | Where-Object { $_.Value -eq $t }).Key
            $TargetComputers[$labId] = $t
        } else {
            Write-Warning "Target '$t' not found in locations"
        }
    }
    $targetDescription = "Specific: $($Target -join ', ')"
} elseif ($TargetRooms) {
    # Target by rooms
    $TargetComputers = Get-RoomComputers -Rooms $TargetRooms -Domain $Domain
    $targetDescription = "Rooms: $($TargetRooms -join ', ')"
} else {
    # Default: all rooms
    $TargetComputers = $AllRooms
    $targetDescription = "All Rooms"
}

if ($TargetComputers.Count -eq 0) {
    Write-Host "No valid targets specified. Exiting." -ForegroundColor Red
    return
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remote Execution Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $targetDescription" -ForegroundColor Yellow
Write-Host "Payload: $PayloadName" -ForegroundColor Yellow
Write-Host "Total Computers: $($TargetComputers.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Build the FQDN list (filter out empty values)
$computerList = $TargetComputers.Values | 
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
$report = foreach ($entry in $TargetComputers.GetEnumerator()) {
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

# Output the report - RAW format for ZERO truncation
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "COMPLETE Results:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

foreach ($entry in ($report | Sort-Object LabID)) {
    Write-Host "`n$($entry.LabID.PadRight(12)) | $($entry.Hostname.PadRight(15)) |" -NoNewline -ForegroundColor Cyan
    Write-Host $entry.Status -ForegroundColor White
}

# Summary
$online = ($report | Where-Object { $_.Status -ne "OFFLINE / UNREACHABLE" }).Count
$offline = ($report | Where-Object { $_.Status -eq "OFFLINE / UNREACHABLE" }).Count

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Online/Responded: $online" -ForegroundColor Green
Write-Host "  Offline/Unreachable: $offline" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

