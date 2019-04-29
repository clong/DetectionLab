#! /bin/bash

set -e

# Create artifacts directory
if [ ! -d "/tmp/artifacts" ]; then
  mkdir /tmp/artifacts
fi

## Provision a Type1 baremetal Packet.net server
echo "[$(date +%H:%M:%S)]: Provisioning a server on Packet.net"
DEVICE_ID=$(curl -s -X POST --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" -d '{ "facility": "sjc1", "plan": "baremetal_1", "hostname": "detectionlab", "description": "testing", "billing_cycle": "hourly", "operating_system": "ubuntu_16_04", "userdata": "", "locked": "false", "project_ssh_keys": ["315a9565-d5b1-41b6-913d-fcf022bb89a6", "755b134a-f63c-4fc5-9103-c1b63e65fdfc"] }' 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."id" | tr -d '"')
# Make sure the device ID is sane.
# TODO: maybe make this a regex
if [ "$(echo -n $DEVICE_ID | wc -c)" -ne 36 ]; then
  echo "[$(date +%H:%M:%S)]: Server may have failed provisionining. Device ID is set to: $DEVICE_ID"
  echo "[$(date +%H:%M:%S)]: This usually happens if there are no servers available in the selected datacenter."
  echo "[$(date +%H:%M:%S)]: Attempting to retry in another datacenter..."
  DEVICE_ID=$(curl -s -X POST --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" -d '{ "facility": "ewr1", "plan": "baremetal_1", "hostname": "detectionlab", "description": "testing", "billing_cycle": "hourly", "operating_system": "ubuntu_16_04", "userdata": "", "locked": "false", "project_ssh_keys": ["315a9565-d5b1-41b6-913d-fcf022bb89a6", "755b134a-f63c-4fc5-9103-c1b63e65fdfc"] }' 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."id" | tr -d '"')
  if [ "$(echo -n $DEVICE_ID | wc -c)" -ne 36 ]; then
    echo "[$(date +%H:%M:%S)]: This script was still unable to successfully provision a server. Exiting."
    exit 1
  fi
fi
echo "[$(date +%H:%M:%S)]: Server successfully created with ID: $DEVICE_ID"

echo "[$(date +%H:%M:%S)]: Waiting for server to finish provisioning..."
# Continue to poll the API until the state of the host is "active"
STATE="provisioning"
while [ "$STATE" != "active" ]; do
  sleep 10
  echo "[$(date +%H:%M:%S)]: Sleeping for 10 seconds. Server is still $STATE."
  STATE="$(curl -s --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" "https://api.packet.net/devices/$DEVICE_ID" | jq .state | tr -d '"')"
done
echo "[$(date +%H:%M:%S)]: Device with ID $DEVICE_ID has finished provisioning! Onto the build process..."

## Recording the IP address of the newly provisioned Packet server
IP_ADDRESS=$(curl -s -X GET --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" "https://api.packet.net/devices/$DEVICE_ID/ips" | jq ."ip_addresses[0].address" | tr -d '"')

# Copy repo to Packet server
# TODO: Tar up the repo and expand it remotely
cd ~/repo
rsync -Paq -e "ssh -i ~/.ssh/id_rsa" ~/repo/ root@"$IP_ADDRESS":/opt/DetectionLab

## Running install script on Packet server
ssh -i ~/.ssh/id_rsa root@"$IP_ADDRESS" 'bash -s' -- < ci/build_machine_bootstrap.sh --vagrant-only

## Waiting for Packet server to post build results
MINUTES_PAST=0
while [ "$MINUTES_PAST" -lt 180 ]; do
  STATUS=$(curl $IP_ADDRESS)
  if [ "$STATUS" == "building" ]; then
    echo "[$(date +%H:%M:%S)]: $STATUS"
    scp -q -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_up_*.log /tmp/artifacts/ || echo "Vagrant log not yet present"
    sleep 300
    ((MINUTES_PAST += 5))
  else
    scp -q -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_up_*.log /tmp/artifacts/ || echo "Vagrant log not yet present"
    break
  fi
  if [ "$MINUTES_PAST" -gt 180 ]; then
    echo "[$(date +%H:%M:%S)]: Serer timed out. Uptime: $MINUTES_PAST minutes."
    scp -q -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_up_*.log /tmp/artifacts/
    curl -s -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
    exit 1
  fi
done

## Recording the build results
echo "[$(date +%H:%M:%S)]: $STATUS"
if [ "$STATUS" != "success" ]; then
  scp -q -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_up_*.log /tmp/artifacts/
  echo "Build failed. Cleaning up server with ID $DEVICE_ID"
  curl -s -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
  exit 1
fi
echo "[$(date +%H:%M:%S)]: Build was successful. Cleaning up server with ID $DEVICE_ID"
curl -s -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
exit 0
