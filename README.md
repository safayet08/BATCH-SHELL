# Remote Execution Runner

Execute payloads on remote lab computers via PowerShell remoting.

## Usage

### Target entire rooms
```powershell
# Single room
.\Runner.ps1 -TargetRooms "MKH4010" -PayloadName "VerifyArduinoCLI"

# Multiple rooms
.\Runner.ps1 -TargetRooms "MKH4000","MKH4005","MKH4010" -PayloadName "SystemInfo"

# All rooms (default if no target specified)
.\Runner.ps1 -PayloadName "DiskSpace"
```

### Target specific computers
```powershell
# Single computer by LabID
.\Runner.ps1 -TargetComputers "MKH-4025-04" -PayloadName "VerifyArduinoCLI"

# Multiple specific computers
.\Runner.ps1 -TargetComputers "MKH-4025-04","MKH-4010-01","MKH-4005-12" -PayloadName "DeployPicoCore"
```

## Available Payloads

| Payload | Description |
|---------|-------------|
| `VerifyArduinoCLI` | Check if Arduino CLI is installed |
| `DeployArduinoCLI` | Install Arduino CLI via Chocolatey |
| `VerifyPicoCore` | Check if RP2040/PICO core is installed |
| `DeployPicoCore` | Install RP2040/PICO core (adds board URL, updates index, installs) |
| `SystemInfo` | Get computer name, OS, RAM, last boot time |
| `DiskSpace` | Get disk space information |
| `InstalledPrograms` | List installed programs |
| `InstallChocolatey` | Install Chocolatey package manager |
| `CheckChocolatey` | Check if Chocolatey is installed |
| `CheckFaronicsInsight` | Check if Faronics Insight Student is installed |
| `CheckIntelliJ` | Check if IntelliJ IDEA is installed |
| `CheckPyCharm` | Check if PyCharm is installed |
| `CheckArduinoIDE` | Check if Arduino IDE is installed |
| `CheckLabtestFiles` | Check Labtest/Exam system files (GPO sync) |

## Available Rooms

- `MKH4000` - 32 computers
- `MKH4005` - 48 computers
- `MKH4010` - 48 computers
- `MKH4015` - 28 computers
- `MKH4025` - 50 computers

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TargetRooms` | No | Array of room names (e.g., "MKH4010","MKH4005") |
| `-TargetComputers` | No | Array of specific LabIDs (e.g., "MKH-4025-04") |
| `-PayloadName` | No | Payload to execute (default: VerifyArduinoCLI) |
| `-Domain` | No | Domain suffix (default: yorku.yorku.ca) |

**Note:** If both `-TargetRooms` and `-TargetComputers` are provided, `-TargetComputers` takes precedence.
