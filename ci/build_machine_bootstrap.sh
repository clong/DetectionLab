#! /usr/bin/env bash

# This script is run on the Packet.net baremetal server for CI tests.
# While building, the server will start a webserver on Port 80 that contains
# the text "building". Once the test is completed, the text will be replaced
# with "success" or "failed".

export DEBIAN_FRONTEND=noninteractive
# Bypass prompt for libsslv1.1 https://unix.stackexchange.com/a/543706
echo 'libssl1.1:amd64 libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Download Packet.net storage utilities
echo "[$(date +%H:%M:%S)]: Downloading Packet external storage utilities..."
wget -q -O /usr/local/bin/packet-block-storage-attach "https://raw.githubusercontent.com/packethost/packet-block-storage/master/packet-block-storage-attach"
chmod +x /usr/local/bin/packet-block-storage-attach
wget -q -O /usr/local/bin/packet-block-storage-detach "https://raw.githubusercontent.com/packethost/packet-block-storage/master/packet-block-storage-detach"
chmod +x /usr/local/bin/packet-block-storage-detach

# Set a flag to determine if the boxes are available on external Packet storage
BOXES_PRESENT=0
# Attempt to mount the block storage
echo "[$(date +%H:%M:%S)]: Attempting to mount external storage..."
/usr/local/bin/packet-block-storage-attach
sleep 10
# Check if it was successful by looking for volume* in /dev/mapper
if ls -al /dev/mapper/volume* > /dev/null 2>&1; then
  echo "[$(date +%H:%M:%S)]: Mounting of external storage was successful."
  sleep 5
  if mount /dev/mapper/volume-fed37d73-part1 /mnt; then
    echo "[$(date +%H:%M:%S)]: External storage successfully mounted to /mnt"
  else
    echo "[$(date +%H:%M:%S)]: Something went wrong mounting the filesystem from the external storage."
  fi
  if ls -al /mnt/*.box > /dev/null 2>&1; then
    BOXES_PRESENT=1
  fi
else
  echo "[$(date +%H:%M:%S)]: No volumes found after attempting to mount storage. Trying again..."
  /usr/local/bin/packet-block-storage-attach
  sleep 15
  if ! ls -al /dev/mapper/volume* > /dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)]: Failed to mount volumes even after a retry. Giving up..."
  else
    echo "[$(date +%H:%M:%S)]: Successfully mounted the external storage after a retry."
    sleep 10
    if mount /dev/mapper/volume-fed37d73-part1 /mnt; then
      echo "[$(date +%H:%M:%S)]: External storage successfully mounted to /mnt"
    else
      echo "[$(date +%H:%M:%S)]: Something went wrong mounting the filesystem from the external storage."
    fi
    if ls -al /mnt/*.box > /dev/null 2>&1; then
      BOXES_PRESENT=1
    fi
  fi
fi

# Disable IPv6 - may help with the vagrant-reload plugin: https://github.com/hashicorp/vagrant/issues/8795#issuecomment-468945063
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null

# Install Virtualbox 6.1
echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
echo "[$(date +%H:%M:%S)]: Running apt-get update..."
apt-get -qq update
echo "[$(date +%H:%M:%S)]: Running apt-get install..."
apt-get -qq install -y linux-headers-"$(uname -r)" virtualbox-6.1 build-essential unzip git ufw apache2

echo "building" > /var/www/html/index.html

# Set up firewall
ufw allow ssh
ufw allow http
ufw default allow outgoing
ufw --force enable

# Install Vagrant
echo "[$(date +%H:%M:%S)]: Installing Vagrant..."
mkdir /opt/vagrant
cd /opt/vagrant || exit 1
wget --progress=bar:force https://releases.hashicorp.com/vagrant/2.2.10/vagrant_2.2.10_x86_64.deb
dpkg -i vagrant_2.2.10_x86_64.deb
echo "[$(date +%H:%M:%S)]: Installing vagrant-reload plugin..."
vagrant plugin install vagrant-reload

# Make sure the plugin installed correctly. Retry if not.
if [ "$(vagrant plugin list | grep -c vagrant-reload)" -ne "1" ]; then
  echo "[$(date +%H:%M:%S)]: The first attempt to install the vagrant-reload plugin failed. Trying again."
  vagrant plugin install vagrant-reload
fi

# Re-enable IPv6 - may help with the Vagrant Cloud slowness
echo "net.ipv6.conf.all.disable_ipv6=0" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile

# Temporary workaround for VB 6.1 until this is fixed in Vagrant
# https://github.com/clong/DetectionLab/issues/374
sed -i 's/--clipboard/--clipboard-mode/g' /opt/DetectionLab/Vagrant/Vagrantfile

# If the boxes are present on external storage, we can modify the Vagrantfile to
# point to the boxes on disk so we don't have to download them
if [ $BOXES_PRESENT -eq 1 ]; then
  echo "[$(date +%H:%M:%S)]: Updating the Vagrantfile to point to the boxes mounted on external storage..."
  sed -i 's#"detectionlab/win2016"#"/mnt/windows_2016_virtualbox.box"#g' /opt/DetectionLab/Vagrant/Vagrantfile
  sed -i 's#"detectionlab/win10"#"/mnt/windows_10_virtualbox.box"#g' /opt/DetectionLab/Vagrant/Vagrantfile
fi

# Recreate a barebones version of the build script so we have some sense of return codes
cat << 'EOF' > /opt/DetectionLab/build.sh
#! /usr/bin/env bash

# Brings up a single host using Vagrant
vagrant_up_host() {
  HOST="$1"
  (echo >&2 "Attempting to bring up the $HOST host using Vagrant")
  cd "$DL_DIR"/Vagrant || exit 1
  $(which vagrant) up "$HOST" &> "$DL_DIR/Vagrant/vagrant_up_$HOST.log"
  echo "$?"
}

# Attempts to reload and re-provision a host if the intial "vagrant up" fails
vagrant_reload_host() {
  HOST="$1"
  cd "$DL_DIR"/Vagrant || exit 1
  # Attempt to reload the host if the vagrant up command didn't exit cleanly
  $(which vagrant) reload "$HOST" --provision >>"$DL_DIR/Vagrant/vagrant_up_$HOST.log" 2>&1
  echo "$?"
}

# A series of checks to ensure important services are responsive after the build completes.
post_build_checks() {
  # If the curl operation fails, we'll just leave the variable equal to 0
  # This is needed to prevent the script from exiting if the curl operation fails
  SPLUNK_CHECK=$(curl -ks -m 2 https://192.168.38.105:8000/en-US/account/login?return_to=%2Fen-US%2F | grep -c 'This browser is not supported by Splunk' || echo "")
  FLEET_CHECK=$(curl -ks -m 2 https://192.168.38.105:8412 | grep -c 'Kolide Fleet' || echo "")
  ATA_CHECK=$(curl --fail --write-out "%{http_code}" -ks https://192.168.38.103 -m 2)
  [[ $ATA_CHECK == 401 ]] && ATA_CHECK=1

  BASH_MAJOR_VERSION=$(/bin/bash --version | grep 'GNU bash' | grep -oi version\.\.. | cut -d ' ' -f 2 | cut -d '.' -f 1)
  # Associative arrays are only supported in bash 4 and up
  if [ "$BASH_MAJOR_VERSION" -ge 4 ]; then
    declare -A SERVICES
    SERVICES=(["splunk"]="$SPLUNK_CHECK" ["fleet"]="$FLEET_CHECK" ["ms_ata"]="$ATA_CHECK")
    for SERVICE in "${!SERVICES[@]}"; do
      if [ "${SERVICES[$SERVICE]}" -lt 1 ]; then
        (echo >&2 "Warning: $SERVICE failed post-build tests and may not be functioning correctly.")
      fi
    done
  else
    if [ "$SPLUNK_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Splunk failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$FLEET_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: Fleet failed post-build tests and may not be functioning correctly.")
    fi
    if [ "$ATA_CHECK" -lt 1 ]; then
      (echo >&2 "Warning: MS ATA failed post-build tests and may not be functioning correctly.")
    fi
  fi
}

build_vagrant_hosts() {
  LAB_HOSTS=("logger" "dc" "wef" "win10")

  # Vagrant up each box and attempt to reload one time if it fails
  for VAGRANT_HOST in "${LAB_HOSTS[@]}"; do
    RET=$(vagrant_up_host "$VAGRANT_HOST")
    if [ "$RET" -eq 0 ]; then
      (echo >&2 "Good news! $VAGRANT_HOST was built successfully!")
    fi
    # Attempt to recover if the intial "vagrant up" fails
    if [ "$RET" -ne 0 ]; then
      (echo >&2 "Something went wrong while attempting to build the $VAGRANT_HOST box.")
      (echo >&2 "Attempting to reload and reprovision the host...")
      RETRY_STATUS=$(vagrant_reload_host "$VAGRANT_HOST")
      if [ "$RETRY_STATUS" -eq 0 ]; then
        (echo >&2 "Good news! $VAGRANT_HOST was built successfully after a reload!")
      else
        (echo >&2 "Failed to bring up $VAGRANT_HOST after a reload. Exiting.")
        exit 1
      fi
    fi
  done
}

main() {
  # Get location of build.sh
  # https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
  DL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Build and Test Vagrant hosts 
  cd Vagrant
  build_vagrant_hosts
  post_build_checks
}

main
exit 0
EOF
chmod +x /opt/DetectionLab/build.sh

# Start the build in a tmux session
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux send-keys -t "$sn:0" 'cd /opt/DetectionLab && ./build.sh && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html; umount /mnt && /usr/local/bin/packet-block-storage-detach' Enter
