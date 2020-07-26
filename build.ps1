#Requires -Version 4.0

<#
.Synopsis
   This script is used to deploy a fresh install of DetectionLab

.DESCRIPTION
   This scripts runs a series of tests before running through the
   DetectionLab deployment. It checks:

   * If Packer and Vagrant are installed
   * If VirtualBox or VMware are installed
   * If the proper vagrant plugins are available
   * Various aspects of system health

   Post deployment it also verifies that services are installed and
   running.

   If you encounter issues, feel free to open an issue at
   https://github.com/clong/DetectionLab/issues

.PARAMETER ProviderName
  The Hypervisor you're using for the lab. Valid options are 'virtualbox' or 'vmware_desktop'

.PARAMETER PackerOnly
  This switch skips deploying boxes with vagrant after being built by Packer

.PARAMETER VagrantOnly
  This switch skips building Packer boxes and instead downloads from Vagrant Cloud

.EXAMPLE
  build.ps1 -ProviderName virtualbox

  This builds DetectionLab using virtualbox and the default path for Packer (C:\Hashicorp\packer.exe)
.EXAMPLE
  build.ps1 -ProviderName vmware_desktop

  This builds the DetectionLab using VMware and sets the Packer path to 'C:\packer.exe'
.EXAMPLE
  build.ps1 -ProviderName vmware_desktop -VagrantOnly

  This command builds the DetectionLab using VMware and skips the Packer process, downloading the boxes instead.
#>

[cmdletbinding()]
Param(
  # Vagrant provider to use.
  [ValidateSet('virtualbox', 'vmware_desktop')]
  [string]$ProviderName,
  [switch]$PackerOnly,
  [switch]$VagrantOnly
)

$DL_DIR = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$LAB_HOSTS = ('logger', 'dc', 'wef', 'win10')

function install_checker {
  param(
    [string]$Name
  )
  $results = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Select-Object DisplayName
  $results += Get-ItemProperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Select-Object DisplayName

  forEach ($result in $results) {
    if ($result -like "*$Name*") {
      return $true
    }
  }
  return $false
}

function check_packer {
  # Check if Packer is in path
  Try {
    Get-Command packer.exe -ErrorAction Stop | Out-Null
  } Catch {
    Write-Error 'Packer was not found in your PATH. Please correct this before continuing.' -ForegroundColor yellow
    Write-Error 'Please note that packer is not required if you pass the "-VagrantOnly" flag to the build.ps1 script.' -ForegroundColor yellow
    Write-Error 'Packer is only required if you prefer to create boxes from scratch rather than using the pre-built ones.' -ForegroundColor yellow
    break
  }
}
function check_vagrant {
  # Check if Vagrant is in path
  Try {
    Get-Command vagrant.exe -ErrorAction Stop | Out-Null
  }
  Catch {
    Write-Error 'Vagrant was not found. Please correct this before continuing.' -ForegroundColor red
    Break
  }

  # Check Vagrant version >= 2.2.9
  [System.Version]$vagrant_version = $(vagrant --version).Split(' ')[1]
  [System.Version]$version_comparison = 2.2.9

  if ($vagrant_version -lt $version_comparison) {
    Write-Warning 'It is highly recommended to use Vagrant 2.2.9 or above before continuing' -ForegroundColor yellow
  }
}

# Returns false if not installed or true if installed
function check_virtualbox_installed {
  Write-Host '[check_virtualbox_installed] Running..' -ForegroundColor green
  if (install_checker -Name "VirtualBox") {
    Write-Host '[check_virtualbox_installed] Virtualbox found.' -ForegroundColor green
    return $true
  }
  else {
    Write-Host '[check_virtualbox_installed] Virtualbox not found.' -ForegroundColor green
    return $false
  }
}
function check_vmware_workstation_installed {
  Write-Host '[check_vmware_workstation_installed] Running..' -ForegroundColor green
  if (install_checker -Name "VMware Workstation") {
    Write-Host '[check_vmware_workstation_installed] VMware Workstation found.' -ForegroundColor green
    return $true
  }
  else {
    Write-Host '[check_vmware_workstation_installed] VMware Workstation not found.' -ForegroundColor green
    return $false
  }
}

function check_vmware_vagrant_plugin_installed {
  Write-Host '[check_vmware_vagrant_plugin_installed] Running..' -ForegroundColor green
  if (vagrant plugin list | Select-String 'vagrant-vmware-workstation') {
    Write-Host 'The vagrant VMware Workstation plugin is no longer supported.' -ForegroundColor red
    Write-Host 'Please upgrade to the VMware Desktop plugin: https://www.vagrantup.com/docs/vmware/installation.html' -ForegroundColor red
    return $false
  }
  if (vagrant plugin list | Select-String 'vagrant-vmware-desktop') {
    Write-Host '[check_vmware_vagrant_plugin_installed] Vagrant VMware Desktop plugin found.' -ForegroundColor green
    return $true
  }
  else {
    Write-Host 'VMware Workstation is installed, but the vagrant-vmware-desktop plugin is not.' -ForegroundColor yellow
    Write-Host 'Visit https://www.vagrantup.com/vmware/index.html#buy-now for more information on how to purchase ($80) and install it' -ForegroundColor yellow
    Write-Host 'VMware Workstation will not be listed as a provider until the Vagrant plugin has been installed.' -ForegroundColor yellow
    Write-Host 'NOTE: The plugin does not work with trial versions of VMware Workstation' -ForegroundColor yellow
    return $false
  }
}

function list_providers {
  [cmdletbinding()]
  param()
  
  $vboxInstalled = 0
  $vmwareInstalled = 0
  if (check_virtualbox_installed) {
    $vboxInstalled=1
  }
  if (check_vmware_workstation_installed) {
    if (check_vmware_vagrant_plugin_installed) {
      $vmwareInstalled=1
    }
  }
  # Warn users if Virtualbox and VMware Workstation are both installed.
  if (( $vboxInstalled -eq 1 ) -and ( $vmwareInstalled -eq 1 )) {
    Write-Host "NOTE:" -ForegroundColor yellow
    Write-Host "Both VMware Workstation and Virtualbox appear to be installed on this system." -ForegroundColor yellow
    Write-Host "Please consider setting the VAGRANT_DEFAULT_PROVIDER environment variable to prevent confusion." -ForegroundColor yellow
    Write-Host "More details can be found here: https://www.vagrantup.com/docs/providers/default" -ForegroundColor yellow
    Write-Host "Additionally, please ensure only one providers' network adapters are active at any given time." -ForegroundColor yellow
  }
  if (($vboxInstalled -eq 0) -and ($vmwareInstalled -eq 0)) {
    Write-Error 'You need to install a provider such as VirtualBox or VMware Workstation to continue.' -ForegroundColor red
    Write-Error 'Virtualbox is free, the VMware Vagrant Plugin costs $80.' -ForegroundColor red
    break
  }
  while (-Not ($ProviderName -eq 'virtualbox' -or $ProviderName -eq 'vmware_desktop')) {
    Write-Host "Available Providers: "
    if ($vboxInstalled -eq 1) {
      Write-Host '[*] virtualbox' -ForegroundColor green
    }
    if ($vmwareInstalled -eq 1) {
      Write-Host '[*] vmware_desktop' -ForegroundColor green
    }
    $ProviderName = Read-Host 'Which provider would you like to use?'
    Write-Debug "ProviderName = $ProviderName"
    if (-Not ($ProviderName -eq 'virtualbox' -or $ProviderName -eq 'vmware_desktop')) {
      Write-Error "Please choose a valid provider. $ProviderName is not a valid option"
    }
  }
  return $ProviderName
}

function preflight_checks {
  Write-Host '[preflight_checks] Running..' -ForegroundColor green
  # Verify CredentialGuard isn't enabled
  if (('CredentialGuard' -match ((Get-ComputerInfo).DeviceGuardSecurityServicesConfigured) -eq "True")) {
    Write-Host "WARNING: CredentialGuard appears to be enabled on this system which can cause issues with Virtualbox." -ForegroundColor yellow
    Write-Host "See this thread for more info: https://forums.virtualbox.org/viewtopic.php?f=25&t=82106" -ForegroundColor yellow
    $Confirmation = Read-Host "Please type 'y' to continue or any other key to exit: "
    If ($Confirmation.ToLower() -ne "y") {
      Write-Host "You entered \"$Confirmation\", exiting." -ForegroundColor red
      exit 0
    }
  }
  
  if (-Not ($VagrantOnly)) {
    Write-Host '[preflight_checks] Checking if Packer is installed' -ForegroundColor green
    check_packer
  }
  if (-Not ($PackerOnly)) {
    Write-Host '[preflight_checks] Checking if Vagrant is installed' -ForegroundColor green
    check_vagrant

    Write-Host '[preflight_checks] Checking for pre-existing boxes..' -ForegroundColor green
    if ((Get-ChildItem "$DL_DIR\Boxes\*.box").Count -gt 0) {
      Write-Host 'You seem to have at least one .box file present in the Boxes directory already. If you would like fresh boxes downloaded, please remove all .box files from the Boxes directory and re-run this script.' -ForegroundColor yellow
    }

    # Check to see that no Vagrant instances exist
    Write-Host '[preflight_checks] Checking for vagrant instances..' -ForegroundColor green
    $CurrentDir = Get-Location
    Set-Location "$DL_DIR\Vagrant"
    if (($(vagrant status) | Select-String -Pattern "not[ _]created").Count -ne 4) {
      vagrant status
      Write-Host 'You appear to have already created at least one Vagrant instance. This script does not support already created instances.' -ForegroundColor red
      Write-Host 'To continue, cd to the Vagrant directory and run "vagrant destroy -f"' -ForegroundColor red
      Write-Host 'After that completes, "cd .." and re-run this script.' -ForegroundColor red
      Set-Location "$DL_DIR"
      exit 1
    }
    Set-Location $CurrentDir

    # Check available disk space. Recommend 80GB free, warn if less
    Write-Host '[preflight_checks] Checking disk space..' -ForegroundColor green
    $drives = Get-PSDrive | Where-Object {$_.Provider -like '*FileSystem*'}
    $drivesList = @()

    forEach ($drive in $drives) {
      if ($drive.free -lt 80GB) {
        $DrivesList = $DrivesList + $drive
      }
    }

    if ($DrivesList.Count -gt 0) {
      Write-Host "The following drives have less than 80GB of free space. They should not be used for deploying DetectionLab" -ForegroundColor yellow
      forEach ($drive in $DrivesList) {
        Write-Host "[*] $($drive.Name)"
      }
      Write-Host "You can safely ignore this warning if you are deploying DetectionLab to a different drive." -ForegroundColor yellow
    }

    # Ensure the vagrant-reload plugin is installed
    Write-Host '[preflight_checks] Checking if vagrant-reload is installed..' -ForegroundColor green
    if (-Not (vagrant plugin list | Select-String 'vagrant-reload')) {
      Write-Host 'The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.' -ForegroundColor yellow
      (vagrant plugin install 'vagrant-reload')
      if ($LASTEXITCODE -ne 0) {
        Write-Error 'Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.' -ForegroundColor red
        break
      }
    }
  }
  Write-Host '[preflight_checks] Finished.' -ForegroundColor green
}

function packer_build_box {
  param(
    [string]$Box
  )

  Write-Host "[packer_build_box] Running for $Box" -ForegroundColor green
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Packer"
  Write-Host "Using Packer to build the $BOX Box. This can take 90-180 minutes depending on bandwidth and hardware." -ForegroundColor green
  $env:PACKER_LOG=1
  $env:PACKER_LOG_PATH="$DL_DIR\Packer\packer.log"
  &packer @('build', "--only=$PackerProvider-iso", "$box.json")
  Write-Host "[packer_build_box] Finished for $Box. Got exit code: $LASTEXITCODE" -ForegroundColor green

  if ($LASTEXITCODE -ne 0) {
    Write-Error "Something went wrong while attempting to build the $BOX box."
    Write-Host "To file an issue, please visit https://github.com/clong/DetectionLab/issues/"
    break
  }
  Set-Location $CurrentDir
}

function move_boxes {
  Write-Host "[move_boxes] Running.." -ForegroundColor green
  Move-Item -Path $DL_DIR\Packer\*.box -Destination $DL_DIR\Boxes
  if (-Not (Test-Path "$DL_DIR\Boxes\windows_10_$PackerProvider.box")) {
    Write-Host "Windows 10 box is missing from the Boxes directory. Quitting." -ForegroundColor red
    break
  }
  if (-Not (Test-Path "$DL_DIR\Boxes\windows_2016_$PackerProvider.box")) {
    Write-Error "Windows 2016 box is missing from the Boxes directory. Quitting." -ForegroundColor red
    break
  }
  Write-Host "[move_boxes] Finished." -ForegroundColor green
}

function vagrant_up_host {
  param(
    [string]$VagrantHost
  )
  Write-Host "[vagrant_up_host] Running for $VagrantHost" -ForegroundColor green
  Write-Host "Attempting to bring up the $VagrantHost host using Vagrant" -ForegroundColor green
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Vagrant"
  Set-Variable VAGRANT_LOG=info
  &vagrant.exe @('up', $VagrantHost, '--provider', "$ProviderName") 2>&1 | Out-File -FilePath ".\vagrant_up_$VagrantHost.log"
  Set-Location $CurrentDir
  Write-Host "[vagrant_up_host] Finished for $VagrantHost. Got exit code: $LASTEXITCODE" -ForegroundColor green
  return $LASTEXITCODE
}

function vagrant_reload_host {
  param(
    [string]$VagrantHost
  )
  Write-Host "[vagrant_reload_host] Running for $VagrantHost" -ForegroundColor green
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Vagrant"
  &vagrant.exe @('reload', $VagrantHost, '--provision') 2>&1 | Out-File -FilePath ".\vagrant_up_$VagrantHost.log" -Append
  Set-Location $CurrentDir
  Write-Host "[vagrant_reload_host] Finished for $VagrantHost. Got exit code: $LASTEXITCODE" -ForegroundColor green
  return $LASTEXITCODE
}

function download {
  param(
    [string]$URL,
    [string]$PatternToMatch,
    [switch]$SuccessOn401

  )
  Write-Host "[download] Running for $URL, looking for $PatternToMatch" -ForegroundColor green
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $wc = New-Object System.Net.WebClient
  try
  {
    $result = $wc.DownloadString($URL)
    if ($result -like "*$PatternToMatch*") {
      Write-Host "[download] Found $PatternToMatch at $URL" -ForegroundColor green
      return $true
    }
    else {
      Write-Host "[download] Could not find $PatternToMatch at $URL" -ForegroundColor red
      return $false
    }
  }
  catch
  {
    if ($_.Exception.InnerException.Response.StatusCode -eq 401 -and $SuccessOn401.IsPresent)
    {
      return $true
    }
    else
    {
      Write-Host "Error occured on webrequest: $_" -ForegroundColor red
      return $false
    }
  }
}

function post_build_checks {

  Write-Host '[post_build_checks] Running Splunk Check.'
  $SPLUNK_CHECK = download -URL 'https://192.168.38.105:8000/en-US/account/login?return_to=%2Fen-US%2F' -PatternToMatch 'This browser is not supported by Splunk'
  Write-Host "[post_build_checks] Splunk Result: $SPLUNK_CHECK"

  Write-Host '[post_build_checks] Running Fleet Check.'
  $FLEET_CHECK = download -URL 'https://192.168.38.105:8412' -PatternToMatch 'Kolide Fleet'
  Write-Host "[post_build_checks] Fleet Result: $FLEET_CHECK"

  Write-Host '[post_build_checks] Running MS ATA Check.'
  $ATA_CHECK = download -URL 'https://192.168.38.103' -SuccessOn401
  Write-Host "[post_build_checks] ATA Result: $ATA_CHECK"

  if ($SPLUNK_CHECK -eq $false) {
    Write-Warning 'Splunk failed post-build tests and may not be functioning correctly.' -ForegroundColor yellow
  }
  if ($FLEET_CHECK -eq $false) {
    Write-Warning 'Fleet failed post-build tests and may not be functioning correctly.' -ForegroundColor yellow
  }
  if ($ATA_CHECK -eq $false) {
    Write-Warning 'MS ATA failed post-build tests and may not be functioning correctly.' -ForegroundColor yellow
  }
}

# If no ProviderName was provided, get a provider
if ($ProviderName -eq $Null -or $ProviderName -eq "") {
  $ProviderName = list_providers
}

# Set Provider variable for use deployment functions
if ($ProviderName -eq 'vmware_desktop') {
  $PackerProvider = 'vmware'
}
else {
  $PackerProvider = 'virtualbox'
}

# Run check functions
preflight_checks

# Build Packer Boxes
if (!($VagrantOnly)) {
  packer_build_box -Box 'windows_2016'
  packer_build_box -Box 'windows_10'
  # Move Packer Boxes
  move_boxes
}

if (!($PackerOnly)) {
  # Vagrant up each box and attempt to reload one time if it fails
  forEach ($VAGRANT_HOST in $LAB_HOSTS) {
    Write-Host "[main] Running vagrant_up_host for: $VAGRANT_HOST" -ForegroundColor green
    $result = vagrant_up_host -VagrantHost $VAGRANT_HOST
    Write-Host "[main] vagrant_up_host finished. Exitcode: $result" -ForegroundColor green
    if ($result -eq '0') {
      Write-Host "Good news! $VAGRANT_HOST was built successfully!" -ForegroundColor green
    }
    else {
      Write-Warning "Something went wrong while attempting to build the $VAGRANT_HOST box." -ForegroundColor yellow
      Write-Host "Attempting to reload and reprovision the host..." -ForegroundColor green
      Write-Host "[main] Running vagrant_reload_host for: $VAGRANT_HOST" -ForegroundColor green
      $retryResult = vagrant_reload_host -VagrantHost $VAGRANT_HOST
      if ($retryResult -ne 0) {
        Write-Error "Failed to bring up $VAGRANT_HOST after a reload. Exiting" -ForegroundColor red
        break
      }
    }
    Write-Host "[main] Finished for: $VAGRANT_HOST" -ForegroundColor green
  }

  Write-Host "[main] Running post_build_checks" -ForegroundColor green
  post_build_checks
  Write-Host "[main] Finished post_build_checks" -ForegroundColor green
}
