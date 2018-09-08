if ($env:PACKER_BUILDER_TYPE -And $($env:PACKER_BUILDER_TYPE).startsWith("hyperv")) {
  Write-Host Skip debloat steps in Hyper-V build.
} else {
  Write-Host Downloading debloat zip
  # GitHub requires TLS 1.2 as of 2/1/2018
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $url="https://github.com/StefanScherer/Debloat-Windows-10/archive/master.zip"
  (New-Object System.Net.WebClient).DownloadFile($url, "$env:TEMP\debloat.zip")
  Expand-Archive -Path $env:TEMP\debloat.zip -DestinationPath $env:TEMP -Force

  # Disable Windows Defender
  Write-host Disable Windows Defender
  $os = (gwmi win32_operatingsystem).caption
  if ($os -like "*Windows 10*") {
    set-MpPreference -DisableRealtimeMonitoring $true
  } else {
    Uninstall-WindowsFeature Windows-Defender-Features
  }

  # Optimize Windows Update
  Write-host Optimize Windows Update
  . $env:TEMP\Debloat-Windows-10-master\scripts\optimize-windows-update.ps1
  Write-host Disable Windows Update
  Set-Service wuauserv -StartupType Disabled

  # Turn off shutdown event tracking
  if ( -Not (Test-Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Reliability'))
  {
    New-Item -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT' -Name Reliability -Force
  }
  Set-ItemProperty -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Name ShutdownReasonOn -Value 0

  rm $env:TEMP\debloat.zip
  rm -recurse $env:TEMP\Debloat-Windows-10-master
}
