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

sed -i 's/archive.ubuntu.com/us.archive.ubuntu.com/g' /etc/apt/sources.list

if [[ "$VAGRANT_ONLY" -eq 1 ]] && [[ "$PACKER_ONLY" -eq 1 ]]; then
  echo "Somehow this build is configured as both packer-only and vagrant-only. This means something has gone horribly wrong."
  exit 1
fi

# Install Virtualbox 5.2
echo "deb http://download.virtualbox.org/virtualbox/debian xenial contrib" >> /etc/apt/sources.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
apt-get update
apt-get install -y linux-headers-"$(uname -r)" virtualbox-5.2 build-essential unzip git ufw apache2

echo "building" > /var/www/html/index.html

# Set up firewall
ufw allow ssh
ufw allow http
ufw default allow outgoing
ufw --force enable

if [ "$PACKER_ONLY" -eq 0 ]; then
  # Install Vagrant
  mkdir /opt/vagrant
  cd /opt/vagrant || exit 1
  wget https://releases.hashicorp.com/vagrant/2.2.2/vagrant_2.2.3_x86_64.deb
  dpkg -i vagrant_2.2.3_x86_64.deb
  vagrant plugin install vagrant-reload

  # Make the Vagrant instances headless
  cd /opt/DetectionLab/Vagrant || exit 1
  sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile
fi

if [ "$VAGRANT_ONLY" -eq 0 ]; then
  # Install Packer
  mkdir /opt/packer
  cd /opt/packer || exit 1
  wget https://releases.hashicorp.com/packer/1.3.2/packer_1.3.2_linux_amd64.zip
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
