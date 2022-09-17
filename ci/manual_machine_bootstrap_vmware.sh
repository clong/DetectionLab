#! /usr/bin/env bash

# This script is used to manually prepare an Ubuntu 16.04 server for DetectionLab building

export DEBIAN_FRONTEND=noninteractive
export SERIALNUMBER="SECRET"

sed -i 's#http://archive.ubuntu.com#http://us.archive.ubuntu.com#g' /etc/apt/sources.list
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install VMWare Workstation 15
apt-get update
apt-get install -y linux-headers-"$(uname -r)" build-essential unzip git ufw apache2 ubuntu-desktop python-pip libxtst6 vagrant
pip install awscli --upgrade --user
cp /root/.local/bin/aws /usr/local/bin/aws && chmod +x /usr/local/bin/aws

wget -O VMware-Workstation-Full-16.2.0-18760230.x86_64.bundle "https://download3.vmware.com/software/wkst/file/VMware-Workstation-Full-16.2.0-18760230.x86_64.bundle"
chmod +x VMware-Workstation-Full-16.2.0-18760230.x86_64.bundle
sudo sh VMware-Workstation-Full-16.2.0-18760230.x86_64.bundle --console --required --eulas-agreed --set-setting vmware-workstation serialNumber $SERIALNUMBER

# Set up firewall
ufw allow ssh
ufw default allow outgoing
ufw --force enable

git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab

# Disable IPv6 - may help with the vagrant-reload plugin: https://github.com/hashicorp/vagrant/issues/8795#issuecomment-468945063
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf > /dev/null
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-vmware-desktop
wget --progress=bar:force "https://releases.hashicorp.com/vagrant-vmware-utility/1.0.20/vagrant-vmware-utility_1.0.20_x86_64.deb"
dpkg -i vagrant-vmware-utility_1.0.20_x86_64.deb

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/v.gui = true/v.gui = false/g' Vagrantfile
cd /opt/DetectionLab/Vagrant/Exchange || exit 1
sed -i 's/v.gui = true/v.gui = false/g' Vagrantfile
cd /opt/DetectionLab/Vagrant || exit 1

# Install Packer
mkdir /opt/packer
cd /opt/packer || exit 1
wget --progress=bar:force https://releases.hashicorp.com/packer/1.7.3/packer_1.7.3_linux_amd64.zip
unzip packer_1.7.3_linux_amd64.zip
cp packer /usr/local/bin/packer

# Make the Packer images headless
cd /opt/DetectionLab/Packer || exit 1
for file in *.json; do
  sed -i 's/"headless": false,/"headless": true,/g' "$file";
done