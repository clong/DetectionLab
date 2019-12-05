#! /bin/bash

# This script is run on the Packet.net baremetal server for CI tests.
# While building, the server will start a webserver on Port 80 that contains
# the text "building". Once the test is completed, the text will be replaced
# with "success" or "failed".

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

# Install Virtualbox 5.2
echo "deb http://download.virtualbox.org/virtualbox/debian xenial contrib" >> /etc/apt/sources.list
sed -i "2ideb mirror://mirrors.ubuntu.com/mirrors.txt xenial main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-updates main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-backports main restricted universe multiverse\ndeb mirror://mirrors.ubuntu.com/mirrors.txt xenial-security main restricted universe multiverse" /etc/apt/sources.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
echo "[$(date +%H:%M:%S)]: Running apt-get update..."
apt-get -qq update
echo "[$(date +%H:%M:%S)]: Running apt-get install..."
apt-get -qq install -y linux-headers-"$(uname -r)" virtualbox-5.2 build-essential unzip git ufw apache2

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
wget --progress=bar:force https://releases.hashicorp.com/vagrant/2.2.6/vagrant_2.2.6_x86_64.deb
dpkg -i vagrant_2.2.6_x86_64.deb
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

# If the boxes are present on external storage, we can modify the Vagrantfile to
# point to the boxes on disk so we don't have to download them
if [ $BOXES_PRESENT -eq 1 ]; then
  echo "[$(date +%H:%M:%S)]: Updating the Vagrantfile to point to the boxes mounted on external storage..."
  sed -i 's#"detectionlab/win2016"#"/mnt/windows_2016_virtualbox.box"#g' /opt/DetectionLab/Vagrant/Vagrantfile
  sed -i 's#"detectionlab/win10"#"/mnt/windows_10_virtualbox.box"#g' /opt/DetectionLab/Vagrant/Vagrantfile
fi

# Make the build script is executable
chmod +x /opt/DetectionLab/build.sh
cd /opt/DetectionLab || exit 1

# Start the build in a tmux session
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux send-keys -t "$sn:0" './build.sh virtualbox --vagrant-only && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html; umount /mnt && /usr/local/bin/packet-block-storage-detach' Enter
