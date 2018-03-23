#! /bin/bash

set -e

# Create artifacts directory
if [ ! -d "/tmp/artifacts" ]; then
  mkdir /tmp/artifacts
fi

## Delete stale servers if they exist
DELETE_DEVICE_ID=$(curl -X GET -s --header 'Accept: application/json' --header 'X-Auth-Token:  '"$PACKET_API_TOKEN" 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."devices[0].id" | tr -d '"')
if [ "$(echo -n $DELETE_DEVICE_ID | wc -c)" -eq 36 ]; then
  echo "Requesting deletion for Packet server with ID $DELETE_DEVICE_ID"
  curl -X -s DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DELETE_DEVICE_ID"
fi

## Provision a Type1 baremetal Packet.net server
echo "Provisioning a server on Packet.net"
DEVICE_ID=$(curl -s -X POST --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" -d '{ "facility": "sjc1", "plan": "baremetal_1", "hostname": "detectionlab", "description": "testing", "billing_cycle": "hourly", "operating_system": "ubuntu_16_04", "userdata": "", "locked": "false", "project_ssh_keys": ["315a9565-d5b1-41b6-913d-fcf022bb89a6", "755b134a-f63c-4fc5-9103-c1b63e65fdfc"] }' 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."id" | tr -d '"')
# Make sure the device ID is sane.
# TODO: maybe make this a regex
if [ "$(echo -n $DEVICE_ID | wc -c)" -ne 36 ]; then
  echo "Server may have failed provisionining. Device ID is set to: $DEVICE_ID"
  exit 1
fi
echo "Server successfully provisioned with ID: $DEVICE_ID"

echo "Sleeping 10 minutes to wait for Packet server to be provisioned"
sleep 300
echo "Sleeping 5 more minutes (CircleCI Keepalive)"
sleep 300

## Recording the IP address of the newly provisioned Packet server
IP_ADDRESS=$(curl -s -X GET --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" "https://api.packet.net/devices/$DEVICE_ID/ips" | jq ."ip_addresses[0].address" | tr -d '"')

# Copy repo to Packet server
# TODO: Tar up the repo and expand it remotely
cd ~/repo
rsync -Pav -e "ssh -i ~/.ssh/id_rsa" ~/repo/ root@"$IP_ADDRESS":/opt/DetectionLab

## Running install script on Packet server
ssh -i ~/.ssh/id_rsa root@"$IP_ADDRESS" 'bash -s' -- < ci/build_machine_bootstrap.sh --vagrant-only

## Waiting for Packet server to post build results
MINUTES_PAST=0
while [ "$MINUTES_PAST" -lt 120 ]; do
  STATUS=$(curl $IP_ADDRESS)
  if [ "$STATUS" == "building" ]; then
    echo "$STATUS"
    scp -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_build.log /tmp/artifacts/vagrant_build.log || echo "vagrant_build.log not available yet"
    sleep 300
    ((MINUTES_PAST += 5))
  else
    break
  fi
  if [ "$MINUTES_PAST" -gt 120 ]; then
    echo "Serer timed out. Uptime: $MINUTES_PAST minutes."
    scp -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_build.log /tmp/artifacts/vagrant_build.log
    curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
    exit 1
  fi
done

## Recording the build results
echo $STATUS
if [ "$STATUS" != "success" ]; then
  scp -i ~/.ssh/id_rsa root@"$IP_ADDRESS":/opt/DetectionLab/Vagrant/vagrant_build.log /tmp/artifacts/vagrant_build.log
  echo "Build failed. Cleaning up server with ID $DEVICE_ID"
  curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
  exit 1
fi
echo "Build was successful. Cleaning up server with ID $DEVICE_ID"
curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DEVICE_ID"
exit 0
