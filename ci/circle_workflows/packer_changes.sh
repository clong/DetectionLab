#! /bin/bash

set -e

# Create artifacts directory
if [ ! -d "/tmp/artifacts" ]; then
  mkdir /tmp/artifacts
fi

## Delete stale servers if they exist
echo "Deleting stale Packet.net servers"
DELETE_DEVICE_ID=$(curl -X GET -s --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."devices[0].id" | tr -d '"')
if [ "$(echo -n $DELETE_DEVICE_ID | wc -c)" -eq 36 ]; then
  echo "Requesting deletion for Packet server with ID $DELETE_DEVICE_ID"
  curl -X DELETE -s --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$DELETE_DEVICE_ID"
fi

## Provision two Type1 baremetal Packet.net servers
echo "Provisioning packerwindows2016 on Packet.net"
SERVER1_ID=$(curl -X POST -s --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" -d '{ "facility": "sjc1", "plan": "baremetal_1", "hostname": "packerwindows2016", "description": "testing", "billing_cycle": "hourly", "operating_system": "ubuntu_16_04", "userdata": "", "locked": "false", "project_ssh_keys":["315a9565-d5b1-41b6-913d-fcf022bb89a6", "755b134a-f63c-4fc5-9103-c1b63e65fdfc"] }' 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."id" | tr -d '"')
if [ "$(echo -n $SERVER1_ID | wc -c)" -ne 36 ]; then
  echo "Server may have failed provisionining. Device ID is set to: $SERVER1_ID"
  exit 1
fi
echo "packerwindows2016 successfully provisioned with ID: $SERVER1_ID"

sleep 5 # Wait a bit before issuing another provision command

echo "Provisioning packerwindows10 on Packet.net"
SERVER2_ID=$(curl -X POST -s --header 'Accept: application/json' --header 'Content-Type: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" -d '{ "facility": "sjc1", "plan": "baremetal_1", "hostname": "packerwindows10", "description": "testing", "billing_cycle": "hourly", "operating_system": "ubuntu_16_04", "userdata": "", "locked": "false", "project_ssh_keys":["315a9565-d5b1-41b6-913d-fcf022bb89a6", "755b134a-f63c-4fc5-9103-c1b63e65fdfc"] }' 'https://api.packet.net/projects/0b3f4f2e-ff05-41a8-899d-7923f620ca85/devices' | jq ."id" | tr -d '"')
if [ "$(echo -n $SERVER2_ID | wc -c)" -ne 36 ]; then
  echo "Server may have failed provisionining. Device ID is set to: $SERVER2_ID"
  exit 1
fi
echo "packerwindows10 successfully provisioned with ID: $SERVER2_ID"

echo "Sleeping 10 minutes to wait for Packet servers to finish provisiong"
sleep 300
echo "Sleeping 5 more minutes (CircleCI Keepalive)"
sleep 300

## Recording the IP address of the newly provisioned Packet servers
SERVER1_IP_ADDRESS=$(curl -X GET --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" "https://api.packet.net/devices/$SERVER1_ID/ips" | jq ."ip_addresses[0].address" | tr -d '"')
SERVER2_IP_ADDRESS=$(curl -X GET --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" "https://api.packet.net/devices/$SERVER2_ID/ips" | jq ."ip_addresses[0].address" | tr -d '"')

# Copy repo to Packet servers
# TODO: Tar up the repo and expand it remotely
cd ~/repo
rsync -Pav -e "ssh -i ~/.ssh/id_rsa" ~/repo/ root@"$SERVER1_IP_ADDRESS":/opt/DetectionLab
rsync -Pav -e "ssh -i ~/.ssh/id_rsa" ~/repo/ root@"$SERVER2_IP_ADDRESS":/opt/DetectionLab

## Running install script on Packet server
ssh -i ~/.ssh/id_rsa root@"$SERVER1_IP_ADDRESS" 'bash -s' -- < ci/build_machine_bootstrap.sh --packer-only
ssh -i ~/.ssh/id_rsa root@"$SERVER2_IP_ADDRESS" 'bash -s' -- < ci/build_machine_bootstrap.sh --packer-only

sleep 30

## Waiting for Packet server to post build results
MINUTES_PAST=0
while [ "$MINUTES_PAST" -lt 150 ]; do
  SERVER1_STATUS=$(curl $SERVER1_IP_ADDRESS)
  SERVER2_STATUS=$(curl $SERVER2_IP_ADDRESS)
  if [[ "$SERVER1_STATUS" == "building" ]] || [[ "$SERVER2_STATUS" == "building" ]]; then
    echo "$SERVER1_STATUS" :: "$SERVER2_STATUS"
    scp -i ~/.ssh/id_rsa root@"$SERVER1_IP_ADDRESS":/opt/DetectionLab/Packer/packer_build.log /tmp/artifacts/server1_packer.log
    scp -i ~/.ssh/id_rsa root@"$SERVER2_IP_ADDRESS":/opt/DetectionLab/Packer/packer_build.log /tmp/artifacts/server2_packer.log
    sleep 300
    ((MINUTES_PAST += 5))
  fi
  if [[ "$SERVER1_STATUS" != "building" ]] && [[ "$SERVER2_STATUS" != "building" ]]; then
    break
  fi
  if [ "$MINUTES_PAST" -gt 150 ]; then
    echo "Serer timed out. Uptime: $MINUTES_PAST minutes."
    curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER1_ID"
    curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER2_ID"
    exit 1
  fi
done

## Recording the build results
echo "Server1 Status: $SERVER1_STATUS"
echo "Server2 Status: $SERVER2_STATUS"
if [ "$SERVER1_STATUS" != "success" ]; then
  echo "Build failed. Cleaning up server with ID $SERVER1_ID"
  scp -i ~/.ssh/id_rsa root@"$SERVER1_IP_ADDRESS":/opt/DetectionLab/Packer/packer_build.log /tmp/artifacts/server1_packer.log || echo "Serveer1 packer_build.log not available yet"
  curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER1_ID"
  exit 1
fi
if [ "$SERVER2_STATUS" != "success" ]; then
  echo "Build failed. Cleaning up server with ID $SERVER2_ID"
  scp -i ~/.ssh/id_rsa root@"$SERVER2_IP_ADDRESS":/opt/DetectionLab/Packer/packer_build.log /tmp/artifacts/server2_packer.log || echo "Server2 packer_build.log not available yet"
  curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER2_ID"
  exit 1
fi
echo "Builds were successful. Cleaning up servers with IDs $SERVER1_ID and $SERVER2_ID"
curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER1_ID"
curl -X DELETE --header 'Accept: application/json' --header 'X-Auth-Token: '"$PACKET_API_TOKEN" 'https://api.packet.net/devices/'"$SERVER2_ID"
exit 0
