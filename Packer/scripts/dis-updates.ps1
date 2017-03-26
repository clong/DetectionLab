<#
.SYNOPSIS
   Disables automatic windows updates
.DESCRIPTION
   Disables checking for and applying Windows Updates (does not prevent updates from being applied manually or being pushed down)
   Run on the machine that updates need disabling on.
.PARAMETER <paramName>
   None
.EXAMPLE
   ./Disable-WindowsUpdates.ps1
#>
$RunningAsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($RunningAsAdmin)
{

	$Updates = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Settings

	if ($Updates.ReadOnly -eq $True) { Write-Error "Cannot update Windows Update settings due to GPO restrictions." }

	else {
		$Updates.NotificationLevel = 1 #Disabled
		$Updates.Save()
		$Updates.Refresh()
		Write-Output "Automatic Windows Updates disabled."
	}
}

else 
{	Write-Warning "Must be executed in Administrator level shell."
	Write-Warning "Script Cancelled!" } 
