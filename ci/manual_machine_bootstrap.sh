#! /bin/bash

# This script is used to manually prepare an Ubuntu 16.04 server for DetectionLab building

sed -i 's/archive.ubuntu.com/us.archive.ubuntu.com/g' /etc/apt/sources.list

# Install Virtualbox 5.2
echo "deb http://download.virtualbox.org/virtualbox/debian xenial contrib" >> /etc/apt/sources.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
apt-get update
apt-get install -y linux-headers-"$(uname -r)" virtualbox-5.2 build-essential unzip git ufw apache2 python-pip
pip install awscli --upgrade --user
cp /root/.local/bin/aws /usr/local/bin/aws && chmod +x /usr/local/bin/aws

# Set up firewall
ufw allow ssh
ufw default allow outgoing
ufw --force enable

git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab

# Install Vagrant
mkdir /opt/vagrant
cd /opt/vagrant || exit 1
wget https://releases.hashicorp.com/vagrant/2.2.6/vagrant_2.2.6_x86_64.deb
dpkg -i vagrant_2.2.6_x86_64.deb

# Disable IPv6 - may help with the vagrant-reload plugin: https://github.com/hashicorp/vagrant/issues/8795#issuecomment-468945063
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null
vagrant plugin install vagrant-reload

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/vb.gui = true/vb.gui = false/g' Vagrantfile

# Install Packer
mkdir /opt/packer
cd /opt/packer || exit 1
wget --progress=bar:force https://releases.hashicorp.com/packer/1.4.1/packer_1.4.1_linux_amd64.zip
unzip packer_1.4.1_linux_amd64.zip
cp packer /usr/local/bin/packer

# Make the Packer images headless
cd /opt/DetectionLab/Packer || exit 1
for file in *.json; do
  sed -i 's/"headless": false,/"headless": true,/g' "$file";
done

# Ensure the script is executable
chmod +x /opt/DetectionLab/build.sh
cd /opt/DetectionLab || exit 1
