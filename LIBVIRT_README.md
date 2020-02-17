# Detection Lab Libvirt build

## Intro

This page contains the instruction to build DetectionLab for Qemu/LibVirt. This is the provider for you *if*:
* You are familiar with LibVirt, virt-manager and Qemu and prefer this software stack instead of VirtualBox
* You are willing to spend a bit more time thinkering with the build process as it is less hands-off than the official DetectionLab

A [step-by-step guide is available here](https://selorasec.wordpress.com/2019/12/03/ad-in-a-box-for-pocs-and-iocs-on-the-cheap-detectionlab-on-libvirt/#Setting_Up_Vagrant).

## Prequisite
### LibVirt

The `libvirt` and `virt-manager` installation walkthrough and documentation is out of scope of this project. To follow along, you need an already working installation of `libvirt`, `virt-manager`, and `QEMU+kvm`. 

### Packer

1.  The [Virtio drivers](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/) ISO needs to be location in the `DetectionLab/Packer/` directory.   

* This is a direct [link to the latest version of the virtio drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso).   
* There's also a "stable" version available [here](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso).  

2. Edit the windows_X.json files
* Make sure the following user-defined variables are pointing to the right thing:
 * `virtio_win_iso` : The ISO containing thethe lastest VirtIO drivers
 * `packer_build_dir` : Where to output the QCOW2 images. It's a temporary directory, the .box files will still be in DetectionLab/Packer

3. Build the images
```
env TMPDIR=/path/to/large/storage/ PACKER_LOG=1 PACKER_LOG_PATH="packer_build.log" packer build --only=qemu windows_2016.json
env TMPDIR=/path/to/large/storage/ PACKER_LOG=1 PACKER_LOG_PATH="packer_build.log" packer build --only=qemu windows_10.json
```

### Vagrant
1. Install the necessary plugins:
* `vagrant plugin install vagrant-reload vagrant-libvirt vagrant-winrm-syncedfolders`
* See the guide for ubuntu as the vagrant packages comes with a ton on unofficial & outdated plugins that will cause problems
2. Add the previously built windows .box files
* `vagrant box add windows_10_libvirt.box --name windows_10_libvirt`
* `vagrant box add windows_2016_libvirt.box --name windows_2016_libvirt`
3. Build: `vagrant up --provider libvirt --no-parallel --provision`

#### Notes: 
The libvirt builder is highly experimental. This sections describes the tradeoffs and the differences between the vanilla DetectionLab.

- No pre-built images and integration with the build.sh script for now. This means building the Windows base boxes with Packer (> 1h) and provisioning with Vagrant manually (> 1h). Fortunately, the process is relatively straightforward.
- The boxes will have two network adapters
The vagrant-libvirt provider works by binding to a "management" network adapter IP addresses. The way vagrant finds the VM's IP address is by probing the dnsmasq lease file of libvirt's host. There's probably a better way, but this is the best I could do that just works (tm) so far. Here's what the configuration looks like:

* Management Network: Isolated network, no NAT, no internet access, with DHCP.
* Detectionlab Network: 192.168.38.0/24, with NAT, with internet access, with DHCP.

- The synced folder is using an old, slow and buggy plugin. While this barely works, it's enough to push the provisioning scripts to the Windows instances. Any modifications to the `vm.synced_folder` in the VagrantFile libvirt provider will likely break the provisionning process

- The graphical and input settings assume the use of virt-manager with the SPICE viewer on Windows and the VNC viewer on Linux (logger). The spice agent for copy/pasting and other quality of life improvement, like auto-resolution changes is *NOT* installed on the Windows hosts. *Guacamole* is a better way to access your VMs.
