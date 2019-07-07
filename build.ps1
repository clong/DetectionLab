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

.PARAMETER PackerPath
  The full path to the packer executable. Default is C:\Hashicorp\packer.exe

.PARAMETER PackerOnly
  This switch skips deploying boxes with vagrant after being built by packer

.PARAMETER VagrantOnly
  This switch skips building packer boxes and instead downloads from Vagrant Cloud

.EXAMPLE
  build.ps1 -ProviderName virtualbox

  This builds the DetectionLab using virtualbox and the default path for packer (C:\Hashicorp\packer.exe)
.EXAMPLE
  build.ps1 -ProviderName vmware_desktop -PackerPath 'C:\packer.exe'

  This builds the DetectionLab using VMware and sets the packer path to 'C:\packer.exe'
.EXAMPLE
  build.ps1 -ProviderName vmware_desktop -VagrantOnly

  This command builds the DetectionLab using vmware and skips the packer process, downloading the boxes instead.
#>

[cmdletbinding()]
Param(
  # Vagrant provider to use.
  [ValidateSet('virtualbox', 'vmware_desktop')]
  [string]$ProviderName,
  [string]$PackerPath = 'C:\Hashicorp\packer.exe',
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
  # Check for packer using Get-Command
  if ((Get-Command packer).Path) {
    $PackerPath = (Get-Command packer).Path
    Write-Output "Packer found at $PackerPath"
  }
  # Check for packer at $PackerPath
  if (!(Test-Path $PackerPath)) {
    Write-Error "Packer not found at $PackerPath"
    Write-Output 'Re-run the script setting the PackerPath parameter to the location of packer'
    Write-Output "Example: build.ps1 -PackerPath 'C:\packer.exe'"
    Write-Output 'Exiting..'
    break
  }
}
function check_vagrant {
  # Check if vagrant is in path
  try {
    Get-Command vagrant.exe -ErrorAction Stop | Out-Null
  }
  catch {
    Write-Error 'Vagrant was not found. Please correct this before continuing.'
    break
  }

  # Check Vagrant version >= 2.2.2
  [System.Version]$vagrant_version = $(vagrant --version).Split(' ')[1]
  [System.Version]$version_comparison = 2.2.2

  if ($vagrant_version -lt $version_comparison) {
    Write-Warning 'It is highly recommended to use Vagrant 2.2.2 or above before continuing'
  }
}

# Returns false if not installed or true if installed
function check_virtualbox_installed {
  Write-Host '[check_virtualbox_installed] Running..'
  if (install_checker -Name "VirtualBox") {
    Write-Host '[check_virtualbox_installed] Virtualbox found.'
    return $true
  }
  else {
    Write-Host '[check_virtualbox_installed] Virtualbox not found.'
    return $false
  }
}
function check_vmware_workstation_installed {
  Write-Host '[check_vmware_workstation_installed] Running..'
  if (install_checker -Name "VMware Workstation") {
    Write-Host '[check_vmware_workstation_installed] VMware Workstation found.'
    return $true
  }
  else {
    Write-Host '[check_vmware_workstation_installed] VMware Workstation not found.'
    return $false
  }
}

function check_vmware_vagrant_plugin_installed {
  Write-Host '[check_vmware_vagrant_plugin_installed] Running..'
  if (vagrant plugin list | Select-String 'vagrant-vmware-desktop') {
    Write-Host 'The vagrant VMware Workstation plugin is no longer supported.'
    Write-Host 'Please upgrade to the VMware Desktop plugin: https://www.vagrantup.com/docs/vmware/installation.html'
    return $false
  }
  if (vagrant plugin list | Select-String 'vagrant-vmware-desktop') {
    Write-Host '[check_vmware_vagrant_plugin_installed] Vagrant VMware Desktop plugin found.'
    return $true
  }
  else {
    Write-Host 'VMware Workstation is installed, but the Vagrant plugin is not.'
    Write-Host 'Visit https://www.vagrantup.com/vmware/index.html#buy-now for more information on how to purchase and install it'
    Write-Host 'VMware Workstation will not be listed as a provider until the Vagrant plugin has been installed.'
    Write-Host 'NOTE: The plugin does not work with trial versions of VMware Workstation'
    return $false
  }
}

function list_providers {
  [cmdletbinding()]
  param()

  Write-Host 'Available Providers: '
  if (check_virtualbox_installed) {
    Write-Host '[*] virtualbox'
  }
  if (check_vmware_workstation_installed) {
    if (check_vmware_vagrant_plugin_installed) {
      Write-Host '[*] vmware_desktop'
    }
  }
  if ((-Not (check_virtualbox_installed)) -and (-Not (check_vmware_workstation_installed))) {
    Write-Error 'You need to install a provider such as VirtualBox or VMware Workstation to continue.'
    break
  }
  while (-Not ($ProviderName -eq 'virtualbox' -or $ProviderName -eq 'vmware_desktop')) {
    $ProviderName = Read-Host 'Which provider would you like to use?'
    Write-Debug "ProviderName = $ProviderName"
    if (-Not ($ProviderName -eq 'virtualbox' -or $ProviderName -eq 'vmware_desktop')) {
      Write-Error "Please choose a valid provider. $ProviderName is not a valid option"
    }
  }
  return $ProviderName
}

function preflight_checks {
  Write-Host '[preflight_checks] Running..'
  # Check to see that no boxes exist
  if (-Not ($VagrantOnly)) {
    Write-Host '[preflight_checks] Checking if Packer is installed'
    check_packer

    # Check Packer Version against known bad
    Write-Host '[preflight_checks] Checking for bad packer version..'
    [System.Version]$PackerVersion = $(& $PackerPath "--version")
    [System.Version]$PackerKnownBad = 1.1.2

    if ($PackerVersion -eq $PackerKnownBad) {
      Write-Error 'Packer 1.1.2 is not supported. Please upgrade to a newer version and see https://github.com/hashicorp/packer/issues/5622 for more information.'
      break
    }
  }
  if (!($PackerOnly)) {
    Write-Host '[preflight_checks] Checking if Vagrant is installed'
    check_vagrant

    Write-Host '[preflight_checks] Checking for pre-existing boxes..'
    if ((Get-ChildItem "$DL_DIR\Boxes\*.box").Count -gt 0) {
      Write-Host 'You seem to have at least one .box file present in the Boxes directory already. If you would like fresh boxes downloaded, please remove all files from the Boxes directory and re-run this script.'
    }

    # Check to see that no vagrant instances exist
    Write-Host '[preflight_checks] Checking for vagrant instances..'
    $CurrentDir = Get-Location
    Set-Location "$DL_DIR\Vagrant"
    if (($(vagrant status) | Select-String -Pattern "not[ _]created").Count -ne 4) {
      Write-Error 'You appear to have already created at least one Vagrant instance. This script does not support already created instances. Please either destroy the existing instances or follow the build steps in the README to continue.'
      break
    }
    Set-Location $CurrentDir

    # Check available disk space. Recommend 80GB free, warn if less
    Write-Host '[preflight_checks] Checking disk space..'
    $drives = Get-PSDrive | Where-Object {$_.Provider -like '*FileSystem*'}
    $drivesList = @()

    forEach ($drive in $drives) {
      if ($drive.free -lt 80GB) {
        $DrivesList = $DrivesList + $drive
      }
    }

    if ($DrivesList.Count -gt 0) {
      Write-Output "The following drives have less than 80GB of free space. They should not be used for deploying DetectionLab"
      forEach ($drive in $DrivesList) {
        Write-Output "[*] $($drive.Name)"
      }
      Write-Output "You can safely ignore this warning if you are deploying DetectionLab to a different drive."
    }

    # Ensure the vagrant-reload plugin is installed
    Write-Host '[preflight_checks] Checking if vagrant-reload is installed..'
    if (-Not (vagrant plugin list | Select-String 'vagrant-reload')) {
      Write-Output 'The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.'
      (vagrant plugin install 'vagrant-reload')
      if ($LASTEXITCODE -ne 0) {
        Write-Error 'Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.'
        break
      }
    }
  }
  Write-Host '[preflight_checks] Finished.'
}

function packer_build_box {
  param(
    [string]$Box
  )

  Write-Host "[packer_build_box] Running for $Box"
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Packer"
  Write-Output "Using Packer to build the $BOX Box. This can take 90-180 minutes depending on bandwidth and hardware."
  $env:PACKER_LOG=1
  $env:PACKER_LOG_PATH="$DL_DIR\Packer\packer.log"
  &$PackerPath @('build', "--only=$PackerProvider-iso", "$box.json")
  Write-Host "[packer_build_box] Finished for $Box. Got exit code: $LASTEXITCODE"

  if ($LASTEXITCODE -ne 0) {
    Write-Error "Something went wrong while attempting to build the $BOX box."
    Write-Output "To file an issue, please visit https://github.com/clong/DetectionLab/issues/"
    break
  }
  Set-Location $CurrentDir
}

function move_boxes {
  Write-Host "[move_boxes] Running.."
  Move-Item -Path $DL_DIR\Packer\*.box -Destination $DL_DIR\Boxes
  if (-Not (Test-Path "$DL_DIR\Boxes\windows_10_$PackerProvider.box")) {
    Write-Error "Windows 10 box is missing from the Boxes directory. Quitting."
    break
  }
  if (-Not (Test-Path "$DL_DIR\Boxes\windows_2016_$PackerProvider.box")) {
    Write-Error "Windows 2016 box is missing from the Boxes directory. Quitting."
    break
  }
  Write-Host "[move_boxes] Finished."
}

function vagrant_up_host {
  param(
    [string]$VagrantHost
  )
  Write-Host "[vagrant_up_host] Running for $VagrantHost"
  Write-Host "Attempting to bring up the $VagrantHost host using Vagrant"
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Vagrant"
  set VAGRANT_LOG=info
  &vagrant.exe @('up', $VagrantHost, '--provider', "$ProviderName") 2>&1 | Out-File -FilePath ".\vagrant_up_$VagrantHost.log"
  Set-Location $CurrentDir
  Write-Host "[vagrant_up_host] Finished for $VagrantHost. Got exit code: $LASTEXITCODE"
  return $LASTEXITCODE
}

function vagrant_reload_host {
  param(
    [string]$VagrantHost
  )
  Write-Host "[vagrant_reload_host] Running for $VagrantHost"
  $CurrentDir = Get-Location
  Set-Location "$DL_DIR\Vagrant"
  &vagrant.exe @('reload', $VagrantHost, '--provision') 2>&1 | Out-File -FilePath ".\vagrant_up_$VagrantHost.log" -Append
  Set-Location $CurrentDir
  Write-Host "[vagrant_reload_host] Finished for $VagrantHost. Got exit code: $LASTEXITCODE"
  return $LASTEXITCODE
}

function download {
  param(
    [string]$URL,
    [string]$PatternToMatch,
    [switch]$SuccessOn401

  )
  Write-Host "[download] Running for $URL, looking for $PatternToMatch"
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $wc = New-Object System.Net.WebClient
  try
  {
    $result = $wc.DownloadString($URL)
    if ($result -like "*$PatternToMatch*") {
      Write-Host "[download] Found $PatternToMatch at $URL"
      return $true
    }
    else {
      Write-Host "[download] Could not find $PatternToMatch at $URL"
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
      Write-Host "Error occured on webrequest: $_"
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
    Write-Warning 'Splunk failed post-build tests and may not be functioning correctly.'
  }
  if ($FLEET_CHECK -eq $false) {
    Write-Warning 'Fleet failed post-build tests and may not be functioning correctly.'
  }
  if ($ATA_CHECK -eq $false) {
    Write-Warning 'MS ATA failed post-build tests and may not be functioning correctly.'
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
    Write-Host "[main] Running vagrant_up_host for: $VAGRANT_HOST"
    $result = vagrant_up_host -VagrantHost $VAGRANT_HOST
    Write-Host "[main] vagrant_up_host finished. Exitcode: $result"
    if ($result -eq '0') {
      Write-Output "Good news! $VAGRANT_HOST was built successfully!"
    }
    else {
      Write-Warning "Something went wrong while attempting to build the $VAGRANT_HOST box."
      Write-Output "Attempting to reload and reprovision the host..."
      Write-Host "[main] Running vagrant_reload_host for: $VAGRANT_HOST"
      $retryResult = vagrant_reload_host -VagrantHost $VAGRANT_HOST
      if ($retryResult -ne 0) {
        Write-Error "Failed to bring up $VAGRANT_HOST after a reload. Exiting"
        break
      }
    }
    Write-Host "[main] Finished for: $VAGRANT_HOST"
  }

  Write-Host "[main] Running post_build_checks"
  post_build_checks
  Write-Host "[main] Finished post_build_checks"
}
