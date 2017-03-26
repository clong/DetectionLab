Write-Host "Install Containers feature"
Install-WindowsFeature -Name Containers

if ((GWMI Win32_Processor).VirtualizationFirmwareEnabled[0] -and (GWMI Win32_Processor).SecondLevelAddressTranslationExtensions[0]) {
  Write-Host "Install Hyper-V feature"
  Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
} else {
  Write-Host "Skipping installation of Hyper-V feature"
}
