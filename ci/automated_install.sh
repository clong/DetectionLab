#! /bin/bash

# This script is run on the Packet.net baremetal server for CI tests.
# This script will build the entire lab from scratch and takes 3-4 hours
# on a Packet.net host
# While building, the server will start a webserver on Port 80 that contains
# the text "building". Once the test is completed, the text will be replaced
# with "success" or "failed".

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

# Install Vagrant
mkdir /opt/vagrant
cd /opt/vagrant || exit 1
wget https://releases.hashicorp.com/vagrant/2.0.3/vagrant_2.0.3_x86_64.deb
dpkg -i vagrant_2.0.3_x86_64.deb
vagrant plugin install vagrant-reload

# Install Packer
mkdir /opt/packer
cd /opt/packer || exit 1
wget https://releases.hashicorp.com/packer/1.1.3/packer_1.1.3_linux_amd64.zip
unzip packer_1.1.3_linux_amd64.zip
cp packer /usr/local/bin/packer

# Make the packer images headless
for file in $(ls *.json); do
  sed -i 's/"headless": false,/"headless": true,/g' "$file";
done

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile

# Ensure the script is executable
chmod +x /opt/DetectionLab/build.sh
cd /opt/DetectionLab || exit 1

# Start the build in a tmux session
sn=tmuxsession
tmux new-session -s "$sn" -d
tmux send-keys -t "$sn:0" './build.sh virtualbox | tee -a /opt/DetectionLab/Vagrant/vagrant.log && echo "success" > /var/www/html/index.html || echo "failed" > /var/www/html/index.html' Enter
