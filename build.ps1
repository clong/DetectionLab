<#
.Synopsis
   This script is used to deploy a fresh install of DetectionLab
.DESCRIPTION
   This scripts runs a series of tests before running through the
   DetectionLab deployment. It checks:

   * If Packer and Vagrant are installed
   * If VirtualBox or VMWare are installed
   * If the proper vagrant plugins are available
   * Various aspects of system health
  
   Post deployment it also verifies that services are installed and
   running. 

.EXAMPLE
   ./build.ps1 -ProviderName virtualbox -PackerPath 'C:\packer.exe'
.EXAMPLE
   ./build.ps1 -ProviderName vmware_workstation -PackerPath 'C:\packer.exe'
#>

Param(
  # Vagrant provider to use.
  [ValidateSet('virtualbox', 'vmware_workstation')]
  [string]$ProviderName,
  [string]$PackerPath = 'C:\Hashicorp\packer.exe'
)


function check_packer_and_vagrant {
  # Check if vagrant is in path
  try {
    Get-Command vagrant.exe -ErrorAction Stop
  }
  catch {
    Write-Error 'Vagrant was not found. Please correct this before continuing.'
    break 
  }

  # Check Vagrant version >= 2.0.0
  [System.Version]$vagrant_version = $(vagrant --version).Split(' ')[1]
  [System.Version]$version_comparison = 2.0.0

  if ($vagrant_version -lt $version_comparison) {
    Write-Warning 'WARNING: It is highly recommended to use Vagrant 2.0.0 or above before continuing'
  }

  #Check for packer at $PackerPath
  if (!(Get-Item $PackerPath)) {
    Write-Output "Packer not found at $PackerPath"
    Write-Output 'Re-run the script setting the PackerPath parameter to the location of packer'
    Write-Output "Example: build.ps1 -PackerPath 'C:\packer.exe'"
    Write-Output 'Exiting..'
    break
  }
}

# Returns 0 if not installed or 1 if installed
function check_virtualbox_installed {
  if (Get-WmiObject Win32_Product -Filter "Name LIKE '%VirtualBox%'") {
    return $true
  }
  else {
    return $false
  }
}
function check_vmware_workstation_installed {
  if (Get-WmiObject Win32_Product -Filter "Name = 'VMWare Workstation'") {
    return $true
  }
  else {
    return $false
  }
} 

#TODO: Verify that the plugin is called 'vagrant-vmware-workstation'
function check_vmware_vagrant_plugin_installed {
  if (!(vagrant plugin list | Select-String 'vagrant-vmware-workstation')) {
    Write-Output 'VMWare Workstation is installed, but the Vagrant plugin is not.'
    Write-Output 'Visit https://www.vagrantup.com/vmware/index.html#buy-now for more information on how to purchase and install it'
    Write-Output 'VMWare Workstation will not be listed as a provider until the Vagrant plugin has been installed.'  
    return $false
  }
  else {
    return $true
  }
}

function list_providers {
  Write-Output 'Available Providers: '
  if (check_virtualbox_installed) {
    Write-Output '[*] virtualbox'
  }
  if (check_vmware_workstation_installed) {
    Write-Output '[*] vmware_workstation'
  }
  if ((-Not (check_virtualbox_installed)) -and (-Not (check_vmware_workstation_installed))) {
    Write-Output 'You need to install a provider such as VirtualBox or VMware Workstation to continue.'
    break
  }
  $ProviderName = Read-Host 'Which provider would you like to use?'
  if ($ProviderName -ne 'virtualbox' -or $ProviderName -ne 'vmware_workstation') {
    Write-Output "Please choose a valid provider. $ProviderName is not a valid option"
    break
  }
  return $ProviderName
}

function preflight_checks {
  $DL_DIR = $MyInvocation.MyCommand.Path

  # Check to see that no boxes exist
  if ((Get-ChildItem "$DL_DIR\Boxes\*.box").Count -gt 0) {
    Write-Output 'You appear to have already built at least one box using Packer. This script does not support pre-built boxes. Please either delete the existing boxes or follow the build steps in the README to continue.'
    break
  }

  # Check to see that no vagrant instances exist
  if (($(vagrant status) | Select-String 'not created').Count -ne 4) {
    Write-Output 'You appear to have already created at least one Vagrant instance. This script does not support already created instances. Please either destroy the existing instances or follow the build steps in the README to continue.'
    break
  }

  # Check available disk space. Recommend 80GB free, warn if less
  $Drives = Get-PSDrive | Where-Object {$_.Provider -like '*FileSystem*'}
  $DrivesList = @()
  
  forEach ($drive in $drives) {
    if ($drive.free -lt 80000000) {
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

  # Check Packer Version against known bad
  [System.Version]$PackerVersion = $(& $PackerPath "--version")
  [System.Version]$PackerKnownBad = 1.1.2

  if ($PackerVersion -eq $PackerKnownBad) {
    Write-Output 'Packer 1.1.2 is not supported. Please upgrade to a newer version and see https://github.com/hashicorp/packer/issues/5622 for more information.'
    break
  }
  
  # Ensure the vagrant-reload plugin is installed
  if (-Not (if (!(vagrant plugin list | Select-String 'vagrant-reload')))) {
    Write-Output 'The vagrant-reload plugin is required and not currently installed. This script will attempt to install it now.'
    (vagrant plugin install 'vagrant-reload')
    if ($LASTEXITCODE -ne 0) {
      Write-Output 'Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.'
      break
    }
  }
}


$DL_DIR = $MyInvocation.MyCommand.Path
$LAB_HOSTS = ('logger', 'dc', 'wef', 'win10')
# If no ProviderName was provided, get a provider
if ($ProviderName -eq $Null) {
  $ProviderName = list_providers
}