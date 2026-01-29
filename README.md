# Single computer by Lab ID
.\Runner.ps1 -Target "MKH-4010-06" -PayloadName "DiskSpace"

# Multiple specific computers
.\Runner.ps1 -Target "MKH-4010-06","MKH-4010-07","MKH-4000-01"

# By hostname instead of Lab ID
.\Runner.ps1 -Target "MKH-W-JY3J8V3" -PayloadName "SystemInfo"

# Still works with rooms
.\Runner.ps1 -TargetRooms "MKH4010" -PayloadName "ArduinoCLI"

# All rooms (default when no target specified)
.\Runner.ps1 -PayloadName "DiskSpace"
