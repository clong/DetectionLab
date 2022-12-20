# explanation of script>
# 1. get list of all IP's on VM
# 2. find interface with ip in correct subnet. I.e. same range as DNS=192.168.56.102
# 3. Change the interfaceMetric of this interface to have higher priority than the others

# Step 1
$ips=Get-NetIPAddress

# Step 2
# Two variables used in while-loop. 
$correctInterfaceIndex=''
[bool]$correctInterface # Cast variable to boolean. Used in while loop
$i=0

# While loop> run until correct interface is found
while ($i -le $ips.Length -and !$correctInterfaceIndex ) {
    #$ips[$i].IPAddress
    if ($ips[$i].IPAddress -like "*192.168.*"){
        $correctInterfaceIndex=$ips[$i].InterfaceIndex
        #$correctInterfaceIndex
    }
    $i++
}

#Step 3
#Get current InterfaceMetric of NetworkInterface with index $correntInterfaceIndex
$current_interface_metric=$(Get-NetIPInterface -InterfaceIndex $correctInterfaceIndex).InterfaceMetric
$current_interface_metric

# Set interfaceMetric with higher priority
Set-NetIPInterface -InterfaceIndex $correctInterfaceIndex -InterfaceMetric $($current_interface_metric-1)
$(Get-NetIPInterface -InterfaceIndex $correctInterfaceIndex).InterfaceMetric