# Purpose: Prepare the AWS AMIs for use

# Hardcode IP addresses in the HOSTS file
If ($env:COMPUTERNAME -eq "DC") {
  Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.56.103    wef.windomain.local'
  Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.56.104    win10.windomain.local'
}
Else {
  Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.56.102    dc.windomain.local'
  Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.56.102    windomain.local'
}

# Keep renewing the IP address until the domain controller is set as a DNS server
while (!(Get-DNSClientServerAddress | Where-Object { $_.ServerAddresses -eq "192.168.56.102" })) { 
  write-host "Waiting to receive the correct DNS settings from DHCP..."; 
  start-sleep 5; 
  ipconfig /renew
}

# Install npcap so Wireshark recognizes the AWS network adapters
Start-Job -ScriptBlock { choco install -y --force npcap --version 0.86 }

# Check if gpupdate works
if ($env:COMPUTERNAME -ne "DC") { 
  Write-Host "Attempting a Group Policy Update..."
  Try {
    Start-Process gpupdate -ArgumentList "/force" -RedirectStandardOutput "c:\Temp\gpupdate_stdout.txt" -RedirectStandardError "c:\Temp\gpupdate_stderr.txt" -ErrorAction Stop
    $stdout = (Get-Content "c:\Temp\gpupdate_stdout.txt")
    Write-Host "$stdout"
  } 
  Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Error: $ErrorMessage"
    $stderr = (Get-Content "c:\Temp\gpupdate_stderr.txt")
    Write-Host $stderr
  }
}



