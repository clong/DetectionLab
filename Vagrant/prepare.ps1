#Requires -Version 4.0

<#
.Synopsis
   This script is used to ensure prerequisites for DetectionLab 
   are properly installed.

.DESCRIPTION
   This scripts runs a series of tests. It checks:

   * If Packer and Vagrant are installed
   * If VirtualBox and/or VMware are installed
   * If the proper vagrant plugins are available
   * Various aspects of system health

   If you encounter issues, feel free to open an issue at
   https://github.com/clong/DetectionLab/issues


.EXAMPLE
  ./prepare.ps1

  This runs a series of checks to ensure your system will successfully be
  able to build DetectionLab.
#>

$VAGRANT_DIR = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$checkmark = ([char]8730)

function install_checker {
  param(
    [string]$Name
  )
  $results = @()
Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
  ForEach-Object {
    $obj = New-Object psobject
      Add-Member -InputObject $obj -MemberType NoteProperty -Name GUID -Value $_.pschildname
      Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $_.GetValue("DisplayName")
      $results += $obj
  }
  forEach ($result in $results) {
    if ($result -like "*$Name*") {
      return $true
    }
  }
  return $false
}

function check_packer_path {
  # Check if Packer is in path
  Try {
    Get-Command packer.exe -ErrorAction Stop | Out-Null
  }
  Catch {
    Write-Host '  [-] Packer was not found in your PATH.' -ForegroundColor yellow
    Write-Host '  [-] This is only needed if you plan to build your own boxes, otherwise you can ignore this message.' -ForegroundColor yellow
  }
}
function check_vagrant_path {
  # Check if Vagrant is in path
  Try {
    Get-Command vagrant.exe -ErrorAction Stop | Out-Null
  }
  Catch {
    Write-Host '  [!] Vagrant was not found in your PATH. Please correct this before continuing.' -ForegroundColor red
    Write-Host '  [!] Correct this by installing Vagrant with Choco or downloading from https://www.vagrantup.com/downloads.html' -ForegroundColor red
    Break
  }

  # Check Vagrant version >= 2.2.9
  [System.Version]$vagrant_version = $(vagrant --version).Split(' ')[1]
  [System.Version]$version_comparison = 2.2.9

  if ($vagrant_version -lt $version_comparison) {
    Write-Host '  [-] It is highly recommended to use Vagrant 2.2.9 or above before continuing' -ForegroundColor yellow
  }
  else {
    Write-Host '  ['$($checkmark)'] Your version of Vagrant ('$vagrant_version') is supported' -ForegroundColor Green
  }
}

# Returns false if not installed or true if installed
function check_virtualbox_installed {
  Write-Host ''
  Write-Host '[+] Checking if Virtualbox is installed...'
  if (install_checker -Name "VirtualBox") {
    Write-Host '  ['$($checkmark)'] Virtualbox found.' -ForegroundColor green
    return $true
  }
  else {
    return $false
  }
}
function check_vmware_workstation_installed {
  Write-Host ''
  Write-Host '[+] Checking if VMware Workstation is installed...'
  if (install_checker -Name "VMware Workstation") {
    Write-Host '  ['$($checkmark)'] VMware Workstation found.' -ForegroundColor green
    return $true
  }
  else {
    return $false
  }
}

function check_vmware_vagrant_plugin_installed {
  Write-Host ''
  Write-Host '[+] Checking if the vagrant_vmware_desktop plugin is installed...' 
  if (vagrant plugin list | Select-String 'vagrant-vmware-workstation') {
    Write-Host '  [!] The vagrant VMware Workstation plugin is no longer supported.' -ForegroundColor red
    Write-Host '  [-] Please upgrade to the VMware Desktop plugin: https://www.vagrantup.com/docs/vmware/installation.html' -ForegroundColor yellow
    Write-Host '  [-] Please also uninstall the vagrant-vmware-fusion plugin and install the vmware-vagrant-desktop plugin' -ForegroundColor yellow
    Write-Host '  [-] HINT: `vagrant plugin uninstall vagrant-vmware-workstation; vagrant plugin install vagrant-vmware-desktop`' -ForegroundColor yellow
    return $false
  }
  if (vagrant plugin list | Select-String 'vagrant-vmware-desktop') {
    Write-Host '  ['$($checkmark)'] Vagrant VMware Desktop plugin found.' -ForegroundColor green
    return $true
  }
  else {
    Write-Host '  [!] VMware Workstation is installed, but the vagrant-vmware-desktop plugin is not.' -ForegroundColor red
    Write-Host '  [-] Visit https://www.vagrantup.com/vmware/index.html#buy-now for more information on how to purchase ($80) and install it' -ForegroundColor yellow
    Write-Host '  [-] VMware Workstation will not be listed as a provider until the Vagrant plugin has been installed.' -ForegroundColor yellow
    Write-Host '  [-] NOTE: The plugin does not work with trial versions of VMware Workstation' -ForegroundColor yellow
    return $false
  }
}

function check_vagrant_vmware_utility_installed {
  Write-Host ''
  Write-Host '[+] Checking if the Vagrant VMware Utility is installed...'
  if (install_checker -Name "Vagrant VMware Utility") {
    Write-Host '  ['$($checkmark)'] Vagrant VMware Utility is installed' -ForegroundColor green
    return $true
  }
  else {
    Write-Host '  [!] To use VMware Workstation as a provider, you need to install the Vagrant VMware Utility.' -ForegroundColor Red
    Write-Host '  [-] To download and install it, visit https://www.vagrantup.com/docs/providers/vmware/vagrant-vmware-utility'
    return $false
  }
}

function list_providers {
  [cmdletbinding()]
  param()
  
  $vboxInstalled = 0
  $vmwareInstalled = 0
  if (check_virtualbox_installed) {
    $vboxInstalled = 1
  }
  if (check_vmware_workstation_installed) {
    if ((check_vmware_vagrant_plugin_installed) -and (check_vagrant_vmware_utility_installed)) {
      $vmwareInstalled = 1
    }
  }
  # Warn users if Virtualbox and VMware Workstation are both installed.
  if (( $vboxInstalled -eq 1 ) -and ( $vmwareInstalled -eq 1 )) {
    Write-Host "  [-] Both VMware Workstation and Virtualbox appear to be installed on this system." -ForegroundColor Yellow
    Write-Host "  [-] Please consider setting the VAGRANT_DEFAULT_PROVIDER environment variable to prevent confusion." -ForegroundColor Yellow
    Write-Host "  [-] More details can be found here: https://www.vagrantup.com/docs/providers/default" -ForegroundColor Yellow
    Write-Host "  [-] Additionally, please ensure only one providers' network adapters are active at any given time." -ForegroundColor Yellow
  }
  if (($vboxInstalled -eq 0) -and ($vmwareInstalled -eq 0)) {
    Write-Host '  [!] You need to install a provider such as VirtualBox or VMware Workstation to continue.' -ForegroundColor Red
    Write-Host '  [!] Virtualbox is free, the VMware Vagrant Plugin costs $80.' -ForegroundColor Red
    break
  }
  Write-Host ''
  Write-Host '[+] Enumerating available providers...'
  Write-Host "[+] Available Providers: "
  if ($vboxInstalled -eq 1) {
    Write-Host '  [*] virtualbox' -ForegroundColor green
  }
  if ($vmwareInstalled -eq 1) {
    Write-Host '  [*] vmware_desktop' -ForegroundColor green
  }
}

function preflight_checks {
  Write-Host ''
  Write-Host '[+] Checking if CredentialGuard is enabled...'
  # Verify CredentialGuard isn't enabled
  if ((Get-ComputerInfo).DeviceGuardSecurityServicesConfigured -match 'CredentialGuard|Credential Guard') {
    Write-Host '  [!] CredentialGuard appears to be enabled on this system which can cause issues with Virtualbox.' -ForegroundColor red
    Write-Host '  [!] See this thread for more info: https://forums.virtualbox.org/viewtopic.php?f=25&t=82106' -ForegroundColor red
  }
  else {
    Write-Host '  ['$($checkmark)'] CredentialGuard is not enabled on this system and will not cause conflicts with VirtualBox.' -ForegroundColor green
  }

  Write-Host ''
  Write-Host '[+] Checking if any boxes have been manually built...' 
  if ((Get-ChildItem "$VAGRANT_DIR\..\Boxes\*.box").Count -gt 0) {
    Write-Host '  [-] You seem to have at least one .box file present in the Boxes directory already.' -ForegroundColor yellow
    Write-Host '  [-] If you would like to use the pre-built boxes, please remove all .box files from the Boxes directory' -ForegroundColor yellow
  }
  else {
    Write-Host '  ['$($checkmark)'] No custom Packer boxes found' -ForegroundColor green
  }

  # Check to see that no Vagrant instances exist
  Write-Host ''
  Write-Host '[+] Checking if any Vagrant instances have been created...'
  $CurrentDir = Get-Location
  Set-Location "$VAGRANT_DIR"
  if (($(vagrant status) | Select-String -Pattern "not[ _]created").Count -ne 4) {
    Write-Host '  [-] You appear to have already created at least one Vagrant instance.' -ForegroundColor yellow
    vagrant status | Select-String 'not[ _]created' -NotMatch | Select-String -Pattern 'logger|dc|wef|win10'
    Write-Host ''
    Write-Host '  [-] If you want to start with a fresh install, you should run `vagrant destroy -f` to remove existing instances.' -ForegroundColor yellow
  }
  else {
    Write-Host '  ['$($checkmark)'] No Vagrant instances have been created' -ForegroundColor green
  }
  Set-Location $CurrentDir

  # Check available disk space. Recommend 80GB free, warn if less
  Write-Host ''
  Write-Host '[+] Checking available disk space...'
  $drives = Get-PSDrive | Where-Object { $_.Provider -like '*FileSystem*' }
  $drivesList = @()

  forEach ($drive in $drives) {
    if ($drive.free -lt 80GB) {
      $DrivesList = $DrivesList + $drive
    }
  }

  if ($DrivesList.Count -gt 0) {
    Write-Host "  [-] The following drives have less than 80GB of free space. They should not be used for deploying DetectionLab" -ForegroundColor yellow
    forEach ($drive in $DrivesList) {
      Write-Host "  [*] $($drive.Name)" -ForegroundColor yellow
    }
    Write-Host '  [-] You can safely ignore this warning if you are deploying DetectionLab to a different drive.' -ForegroundColor yellow
  }
  else {
    Write-Host '  ['$($checkmark)'] You have more than 80GB of free space on your primary partition' -ForegroundColor green
  }

  # Ensure the vagrant-reload plugin is installed
  Write-Host ''
  Write-Host '[+] Checking if vagrant-reload is installed...'
  if (-Not (vagrant plugin list | Select-String 'vagrant-reload')) {
    Write-Host '  [-] The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.' -ForegroundColor yellow
    (vagrant plugin install 'vagrant-reload')
    if ($LASTEXITCODE -ne 0) {
      Write-Host '  [!] Unable to install the vagrant-reload plugin. Please try to do so manually via `vagrant plugin install vagrant-reload` and re-run this script.' -ForegroundColor red
      break
    }
  }
  else {
    Write-Host '  ['$($checkmark)'] The vagrant-reload plugin is installed' -ForegroundColor green
  }
}


# Run check functions
Write-Host ''
Write-Host '[+] Begining pre-build checks for DetectionLab'
Write-Host ''
Write-Host '[+] Checking for necessary tools in PATH...'
check_packer_path
check_vagrant_path
preflight_checks
list_providers

Write-Host ''
Write-Host 'To get started building DetectionLab, simply cd to DetectionLab/Vagrant'
Write-Host 'and run "vagrant up". If you run into any issues along the way, check out'
Write-Host 'the troubleshooting and known issues page: https://www.detectionlab.network/deployment/troubleshooting/'
Write-Host ''
