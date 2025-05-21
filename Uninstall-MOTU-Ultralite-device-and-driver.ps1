# Should be executed as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script should be executed as Administrator."
    exit 1
}

# Check pnputil existence
$pnputilPath = "$env:SystemRoot\System32\pnputil.exe"
if (-not (Test-Path $pnputilPath)) {
    Write-Error "pnputil.exe not found. This script cannot continue."
    exit 1
}

# Étape 1 : Remove devices linked to MOTU or Ultralite
$keywords = "MOTU", "Ultralite"
$devices = Get-PnpDevice -PresentOnly:$false | Where-Object {
    $_.FriendlyName -match ($keywords -join "|") -or $_.InstanceId -match ($keywords -join "|")
}

if ($devices.Count -eq 0) {
    Write-Output "No MOTU our Ultralite device detected in the system."
} else {
    Write-Output "MOTU/Ultralite detected devices :"
    $devices | Format-Table -AutoSize FriendlyName, Status, InstanceId

    foreach ($device in $devices) {
        try {
            Write-Output "Disabling and removing of : $($device.FriendlyName)"
            Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            pnputil /remove-device "$($device.InstanceId)"
        } catch {
            Write-Warning "An error occured during remove of $($device.FriendlyName) : $_"
        }
    }
}

# Étape 2 : Deleting drivers where publisher is "MOTU, Inc"
Write-Output "Searching drivers where the publisher is  'MOTU, Inc'..."

$motuDrivers = (Get-WindowsDriver -online | where ProviderName -eq "MOTU, Inc")

if ($motuDrivers.Count -eq 0) {
    Write-Output "No drivers found with the publisher 'MOTU, Inc'."
} else {
    foreach ($driver in $motuDrivers) {
        $infName = $driver.Driver
        Write-Output "Deleting driver : $infName"
        pnputil /delete-driver "$infName" /uninstall /force
    }
}

Write-Output "Cleaning finished. Please reboot your computer before installing new drivers."
