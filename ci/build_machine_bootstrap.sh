#! /bin/bash

# This script is run on the Packet.net baremetal server for CI tests.
# This script will build the entire lab from scratch and takes 3-4 hours
# on a Packet.net host
# While building, the server will start a webserver on Port 80 that contains
# the text "building". Once the test is completed, the text will be replaced
# with "success" or "failed".

ARGS="$1"
PACKER_ONLY=0
VAGRANT_ONLY=0

if [ ! -z "$1" ]; then
  case "$1" in
    --packer-only)
    PACKER_ONLY=1
    ;;
    --vagrant-only)
    VAGRANT_ONLY=1
    ;;
    *)
    echo "\"$ARGS\" is not a supported argument to this script. Quitting"
    exit 1
    ;;
  esac
fi

echo "Args: $ARGS"

# Disable IPv6 - may help with the vagrant-reload plugin: https://github.com/hashicorp/vagrant/issues/8795#issuecomment-468945063
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

if [[ "$VAGRANT_ONLY" -eq 1 ]] && [[ "$PACKER_ONLY" -eq 1 ]]; then
  echo "[$(date +%H:%M:%S)]: Somehow this build is configured as both packer-only and vagrant-only. This means something has gone horribly wrong."
  exit 1
fi

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

if [ "$PACKER_ONLY" -eq 0 ]; then
  # Install Vagrant
  echo "[$(date +%H:%M:%S)]: Installing Vagrant..."
  mkdir /opt/vagrant
  cd /opt/vagrant || exit 1
  wget --progress=bar:force https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.deb
  dpkg -i vagrant_2.2.4_x86_64.deb
  echo "[$(date +%H:%M:%S)]: Installing vagrant-reload plugin..."
  vagrant plugin install vagrant-reload

  # Make sure the plugin installed correctly. Retry if not.
  if [ "$(vagrant plugin list | grep -c vagrant-reload)" -ne "1" ]; then
    echo "[$(date +%H:%M:%S)]: The first attempt to install the vagrant-reload plugin failed. Trying again."
    vagrant plugin install vagrant-reload
  fi

  # Make the Vagrant instances headless
  cd /opt/DetectionLab/Vagrant || exit 1
  sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile
fi

if [ "$VAGRANT_ONLY" -eq 0 ]; then
  echo "[$(date +%H:%M:%S)]: Installing Packer..."
  # Install Packer
  mkdir /opt/packer
  cd /opt/packer || exit 1
  wget --progress=bar:force https://releases.hashicorp.com/packer/1.3.2/packer_1.3.2_linux_amd64.zip
  unzip packer_1.3.2_linux_amd64.zip
  cp packer /usr/local/bin/packer

  # Make the Packer images headless
  cd /opt/DetectionLab/Packer || exit 1
  for file in *.json; do
    sed -i 's/"headless": false,/"headless": true,/g' "$file";
  done
fi

# Ensure the script is executable
chmod +x /opt/DetectionLab/build.sh
cd /opt/DetectionLab || exit 1

# Start the build in a tmux session
sn=tmuxsession
tmux new-session -s "$sn" -d
if [ "$PACKER_ONLY" -eq 1 ]; then
  tmux send-keys -t "$sn:0" './build.sh virtualbox --packer-only && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html' Enter
fi
if [ "$VAGRANT_ONLY" -eq 1 ]; then
  tmux send-keys -t "$sn:0" './build.sh virtualbox --vagrant-only && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html' Enter
fi
if [[ "$PACKER_ONLY" -eq 0 ]] && [[ "$VAGRANT_ONLY" -eq 0 ]]; then
  tmux send-keys -t "$sn:0" './build.sh virtualbox && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html' Enter
fi
