echo "donwloading virutalbox"
echo "deb https://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
sudo apt update
sudo apt install virtualbox-6.1
wget -P /tmp https://download.virtualbox.org/virtualbox/6.1.0/Oracle_VM_VirtualBox_Extension_Pack-6.1.0.vbox-extpack
sudo VBoxManage extpack install /tmp/Oracle_VM_VirtualBox_Extension_Pack-6.1.0.vbox-extpack

echo "downloading vagrant"
$curl -O https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.deb
$sudo apt install ./vagrant_2.2.9_x86_64.deb
$vagrant plugin install vagrant-reload
