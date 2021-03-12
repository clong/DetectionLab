#!/usr/bin/env bash

# This script is used to prepare DetectionLab to be imported as VM in AWS

# Configure credentials for awscli
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region us-west-1
export BUCKET_NAME="FILL_ME_IN"

cd /opt/DetectionLab/Vagrant || exit 1
echo "Running WinRM Commands to open WinRM on the firewall..."
for host in dc wef win10;
do
  echo "Running 'Set-NetFirewallRule -Name WINRM-HTTP-In-TCP -Profile Any' on $host..."
  vagrant winrm -e -c "Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -Profile Any" -s powershell $host; sleep 2
done
echo "Running 'Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-NoScope -Profile Any' on win10..."
vagrant winrm -c "Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-NoScope' -Profile Any" -s powershell win10; sleep 2

echo "Running WinRM Commands to clear the event logs..."
for host in dc wef win10;
do
  echo "Clearing event logs on $host..."
  vagrant winrm -e -s powershell -c "Clear-Eventlog -Log Application, System" $host
  sleep 2
done

echo "Printing activivation status of all hosts..."
for host in dc wef win10;
do
  echo "$host"
  vagrant winrm -s powershell -c "cscript c:\windows\system32\slmgr.vbs /dlv" $host
  sleep 2
done
echo "If you're ready to continue, type y:"
read READY

if [ "$READY" != "y" ]; then
  echo "Okay, quitting"
  exit 1
fi

#echo "Re-arming WEF"
#vagrant winrm -e -s powershell -c "cscript c:\windows\system32\slmgr.vbs /rearm" wef
#echo "Activating Win10..."
#vagrant winrm -e -s powershell -c "Set-Service TrustedInstaller -StartupType Automatic" win10
#sleep 2
#vagrant winrm -e -s powershell -c "Start-Service TrustedInstaller" win10
#sleep 10
#vagrant winrm -e -s powershell -c "cscript c:\windows\system32\slmgr.vbs /ato " win10

# Stop vagrant and export each box as an OVA
cd /opt/DetectionLab/Vagrant || exit 1
echo "Halting all VMs..."
vagrant halt

echo "Creating a new tmux session..."
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux new-window -t "$sn:2" -n "dc" -d
tmux new-window -t "$sn:3" -n "wef" -d
tmux new-window -t "$sn:4" -n "win10" -d
if which vmrun; then
  tmux send-keys -t "$sn:2" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/dc/vmware_desktop/*/WindowsServer2016.vmx /root/dc.ova && echo -n "success" > /root/dc.export || echo "failed" > /root/dc.export' Enter
  tmux send-keys -t "$sn:3" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/wef/vmware_desktop/*/WindowsServer2016.vmx /root/wef.ova && echo -n "success" > /root/wef.export || echo "failed" > /root/wef.export' Enter
  tmux send-keys -t "$sn:4" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/win10/vmware_desktop/*/windows_10.vmx /root/win10.ova && echo -n "success" > /root/win10.export || echo "failed" > /root/win10.export' Enter
else
  tmux send-keys -t "$sn:2" 'vboxmanage export dc.windomain.local -o /root/dc.ova && echo -n "success" > /root/dc.export || echo "failed" > /root/dc.export' Enter
  tmux send-keys -t "$sn:3" 'vboxmanage export wef.windomain.local -o /root/wef.ova && echo -n "success" > /root/wef.export || echo "failed" > /root/wef.export' Enter
  tmux send-keys -t "$sn:4" 'vboxmanage export win10.windomain.local -o /root/win10.ova && echo -n "success" > /root/win10.export || echo "failed" > /root/win10.export' Enter
fi

# Sleep until all exports are complete
while [[ ! -f /root/dc.export || ! -f /root/wef.export || ! -f /root/win10.export ]];
  do sleep 5
  echo "Waiting for the OVA export to complete. Sleeping for 5."
done

# Copy each OVA into S3
if [[ "$(cat /root/dc.export)" == "success" && "$(cat /root/wef.export)" == "success" && "$(cat /root/win10.export)" == "success" ]]; then
  for file in dc wef win10
  do
    aws s3 cp /root/$file.ova s3://$BUCKET_NAME/disks/
  done
fi

# Fix the bucket
cd /opt/DetectionLab/AWS/Terraform/vm_import || exit 1
for file in *.json;
  do sed -i "s/YOUR_BUCKET_GOES_HERE/$BUCKET_NAME/g" "$file";
done

# Fix the key names
for file in *.json;
  do sed -i 's#"S3Key": "#"S3Key": "disks/#g' "$file";
done

aws ec2 import-image --description "dc" --license-type byol --disk-containers file:///opt/DetectionLab/AWS/Terraform/vm_import/dc.json
aws ec2 import-image --description "wef" --license-type byol --disk-containers file:///opt/DetectionLab/AWS/Terraform/vm_import/wef.json
aws ec2 import-image --description "win10" --license-type byol --disk-containers file:///opt/DetectionLab/AWS/Terraform/vm_import/win10.json
