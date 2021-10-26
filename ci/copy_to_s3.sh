#!/usr/bin/env bash

# This script is used to prepare DetectionLab to be imported as VM in AWS

if ! which aws > /dev/null; then
  apt-get install -y python-pip
  pip install awscli --upgrade --user
  cp /root/.local/bin/aws /usr/local/bin/aws && chmod +x /usr/local/bin/aws
fi

# Configure credentials for awscli
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region us-west-1
export BUCKET_NAME="FILL_ME_IN"

EXCHANGE_EXISTS=0

cd /opt/DetectionLab/Vagrant || exit 1
echo "Clearing out Splunk indexes"
ssh -o StrictHostKeyChecking=no -i /opt/DetectionLab/Vagrant/.vagrant/machines/logger/virtualbox/private_key vagrant@192.168.56.105 'sudo /opt/splunk/bin/splunk stop && sudo /opt/splunk/bin/splunk clean eventdata -f'

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
  vagrant winrm -e -s powershell -c 'wevtutil el | Select-String -notmatch "Microsoft-Windows-LiveId" | Foreach-Object {wevtutil cl "$_"}' $host
  sleep 2
done

echo "Printing activivation status of all hosts..."
for host in dc wef win10;
do
  echo "$host"
  vagrant winrm -s powershell -c "cscript c:\windows\system32\slmgr.vbs /dlv" $host
  sleep 2
done

## Check for exchange box
if ls /opt/DetectionLab/Vagrant/Exchange/.vagrant/machines/exchange/*/id 1> /dev/null 2>&1; then
  EXCHANGE_EXISTS=1
  cd /opt/DetectionLab/Vagrant/Exchange || exit 1
  echo "Exchange appears to have been built. Running the above commands on exchange."
  host="exchange"
  echo "Running 'Set-NetFirewallRule -Name WINRM-HTTP-In-TCP -Profile Any' on $host..."
  vagrant winrm -e -c "Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -Profile Any" -s powershell $host; sleep 2
  echo "Clearing event logs on $host..."
  vagrant winrm -e -s powershell -c 'wevtutil el | Select-String -notmatch "Microsoft-Windows-LiveId" | Foreach-Object {wevtutil cl "$_"}' $host
  echo "Printing activivation status..."
  vagrant winrm -s powershell -c "cscript c:\windows\system32\slmgr.vbs /dlv" $host
fi

echo "If you're ready to continue, type y:"
read READY
if [ "$READY" != "y" ]; then
  echo "Okay, quitting"
  exit 1
fi

# Stop vagrant and export each box as an OVA
cd /opt/DetectionLab/Vagrant || exit 1
echo "Halting all VMs..."
vagrant halt

if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
  cd /opt/DetectionLab/Vagrant/Exchange || exit 1
  echo "Halting Exchange..."
  vagrant halt
fi

echo "Creating a new tmux session..."
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux new-window -t "$sn:2" -n "dc" -d
tmux new-window -t "$sn:3" -n "wef" -d
tmux new-window -t "$sn:4" -n "win10" -d
if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
  tmux new-window -t "$sn:5" -n "exchange" -d
fi

if which vmrun; then
  tmux send-keys -t "$sn:2" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/dc/vmware_desktop/*/WindowsServer2016.vmx /root/dc.ova && echo -n "success" > /root/dc.export || echo "failed" > /root/dc.export' Enter
  tmux send-keys -t "$sn:3" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/wef/vmware_desktop/*/WindowsServer2016.vmx /root/wef.ova && echo -n "success" > /root/wef.export || echo "failed" > /root/wef.export' Enter
  tmux send-keys -t "$sn:4" 'ovftool /opt/DetectionLab/Vagrant/.vagrant/machines/win10/vmware_desktop/*/windows_10.vmx /root/win10.ova && echo -n "success" > /root/win10.export || echo "failed" > /root/win10.export' Enter
  if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
    tmux send-keys -t "$sn:5" 'ovftool /opt/DetectionLab/Vagrant/Exchange/.vagrant/machines/exchange/vmware_desktop/*/exchange.vmx /root/exchange.ova && echo -n "success" > /root/exchange.export || echo "failed" > /root/exchange.export' Enter
  fi
else
  tmux send-keys -t "$sn:2" 'vboxmanage export dc.windomain.local -o /root/dc.ova && echo -n "success" > /root/dc.export || echo "failed" > /root/dc.export' Enter
  tmux send-keys -t "$sn:3" 'vboxmanage export wef.windomain.local -o /root/wef.ova && echo -n "success" > /root/wef.export || echo "failed" > /root/wef.export' Enter
  tmux send-keys -t "$sn:4" 'vboxmanage export win10.windomain.local -o /root/win10.ova && echo -n "success" > /root/win10.export || echo "failed" > /root/win10.export' Enter
  if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
    tmux send-keys -t "$sn:5" 'vboxmanage export exchange.windomain.local -o /root/exchange.ova && echo -n "success" > /root/exchange.export || echo "failed" > /root/exchange.export' Enter
  fi
fi

# Sleep until all exports are complete
while [[ ! -f /root/dc.export || ! -f /root/wef.export || ! -f /root/win10.export ]];
do 
  if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
    if [ ! -f /root/exchange.export ]; then
      sleep 5
      echo "Waiting for the OVA export to complete. Sleeping for 5."
    fi
  else
      sleep 5
      echo "Waiting for the OVA export to complete. Sleeping for 5."
  fi
done

# Copy each OVA into S3
if [[ "$(cat /root/dc.export)" == "success" && "$(cat /root/wef.export)" == "success" && "$(cat /root/win10.export)" == "success" ]]; then
  for file in dc wef win10
  do
    aws s3 cp /root/$file.ova s3://$BUCKET_NAME/disks/
  done
fi

if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
  aws s3 cp /root/exchange.ova s3://$BUCKET_NAME/disks/
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
if [ "$EXCHANGE_EXISTS" -eq 1 ]; then
  aws ec2 import-image --description "exchange" --license-type byol --disk-containers file:///opt/DetectionLab/AWS/Terraform/vm_import/exchange.json
fi
