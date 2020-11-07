#! /usr/bin/env bash

# This script is meant to verify that your system is configured to 
# build DetectionLab successfully.
# Only MacOS and Linux are supported. Use prepare.ps1 for Windows.
# If you encounter issues, feel free to open an issue at
# https://github.com/clong/DetectionLab/issues

ERROR=$(tput setaf 1; echo -n "  [!]"; tput sgr0)
GOODTOGO=$(tput setaf 2; echo -n "  [✓]"; tput sgr0)
INFO=$(tput setaf 3; echo -n "  [-]"; tput sgr0)

print_usage() {
  echo "Usage: ./prepare.sh"
  exit 0
}

check_packer_path() {
  # Check for existence of Packer in PATH
  if ! which packer >/dev/null; then
    (echo >&2 "${INFO} Packer was not found in your PATH.")
    (echo >&2 "${INFO} This is only needed if you plan to build you own boxes, otherwise you can ignore this message.")
  else 
    (echo >&2 "${GOODTOGO} Packer was found in your PATH")
  fi
}

check_vagrant_path() {
  # Check for existence of Vagrant in PATH
  if ! which vagrant >/dev/null; then
    (echo >&2 "${ERROR} Vagrant was not found in your PATH.")
    (echo >&2 "${ERROR} Please correct this before continuing. Exiting.")
    (echo >&2 "${ERROR} Correct this by installing Vagrant with Homebrew or downloading from https://www.vagrantup.com/downloads.html")
    exit 1
  else
    (echo >&2 "${GOODTOGO} Vagrant was found in your PATH")
  fi

  
check_curl_path(){
  # Check to see if curl is in PATH - needed for post-install checks
  if ! which curl >/dev/null; then
    (echo >&2 "${ERROR} Please install curl and make sure it is in your PATH.")
    exit 1
  else 
    (echo >&2 "${GOODTOGO} Curl was found in your PATH")
  fi
}

  # Ensure Vagrant >= 2.2.9
  # https://unix.stackexchange.com/a/285928
  VAGRANT_VERSION="$(vagrant --version | cut -d ' ' -f 2)"
  REQUIRED_VERSION="2.2.9"
  # If the version of Vagrant is not greater or equal to the required version
  if ! [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VAGRANT_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    (echo >&2 "${ERROR} WARNING: It is highly recommended to use Vagrant $REQUIRED_VERSION or above before continuing")
  else 
    (echo >&2 "${GOODTOGO} Your version of Vagrant ($VAGRANT_VERSION) is supported")
  fi
}

# Returns 0 if not installed or 1 if installed
check_virtualbox_installed() {
  if which VBoxManage >/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
# Check for VMWare Workstation on Linux
check_vmware_workstation_installed() {
  if which vmrun >/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_fusion_installed() {
  if [ -e "/Applications/VMware Fusion.app" ]; then
    echo "1"
  else
    echo "0"
  fi
}

# Returns 0 if not installed or 1 if installed
check_vmware_desktop_vagrant_plugin_installed() {
  LEGACY_PLUGIN_CHECK="$(vagrant plugin list | grep -c 'vagrant-vmware-fusion')"
  if [ "$LEGACY_PLUGIN_CHECK" -gt 0 ]; then
    (echo >&2 "${ERROR} The VMware Fusion Vagrant plugin is deprecated and is no longer supported.")
    (echo >&2 "${INFO} Please upgrade to the VMware Desktop plugin: https://www.vagrantup.com/docs/vmware/installation.html")
    (echo >&2 "${INFO} Please also uninstall the vagrant-vmware-fusion plugin and install the vmware-vagrant-desktop plugin")
    (echo >&2 "${INFO} HINT: \`vagrant plugin uninstall vagrant-vmware-fusion && vagrant plugin install vagrant-vmware-desktop\`")
    (echo >&2 "${INFO} NOTE: The VMware plugin does not work with trial versions of VMware Fusion")
    echo "0"
  fi

  VMWARE_DESKTOP_PLUGIN_PRESENT="$(vagrant plugin list | grep -c 'vagrant-vmware-desktop')"
  if [ "$VMWARE_DESKTOP_PLUGIN_PRESENT" -eq 0 ]; then
    (echo >&2 "VMWare Fusion or Workstation is installed, but the vagrant-vmware-desktop plugin is not.")
    (echo >&2 "Visit https://www.hashicorp.com/blog/introducing-the-vagrant-vmware-desktop-plugin for more information on how to purchase and install it")
    (echo >&2 "VMWare Fusion or Workstation will not be listed as a provider until the vagrant-vmware-desktop plugin has been installed.")
    echo "0"
  else
    echo "1"
  fi
}

check_vagrant_vmware_utility_installed() {
  # Ensure the helper utility is installed: https://www.vagrantup.com/docs/providers/vmware/vagrant-vmware-utility
  if pgrep -f vagrant-vmware-utility > /dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# List the available Vagrant providers present on the system
list_providers() {
  VBOX_PRESENT=0
  VMWARE_FUSION_PRESENT=0

  if [ "$(uname)" == "Darwin" ]; then
    # Detect Providers on OSX
    VBOX_PRESENT=$(check_virtualbox_installed)
    VMWARE_FUSION_PRESENT=$(check_vmware_fusion_installed)
    VMWARE_WORKSTATION_PRESENT=0 # Workstation doesn't exist on Darwain-based OS
    VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT=$(check_vmware_desktop_vagrant_plugin_installed)
    VAGRANT_VMWARE_UTILITY_PRESENT=$(check_vagrant_vmware_utility_installed)
  else
    VBOX_PRESENT=$(check_virtualbox_installed)
    VMWARE_WORKSTATION_PRESENT=$(check_vmware_workstation_installed)
    VMWARE_FUSION_PRESENT=0 # Fusion doesn't exist on non-Darwin OS
    VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT=$(check_vmware_desktop_vagrant_plugin_installed)
    VAGRANT_VMWARE_UTILITY_PRESENT=$(check_vagrant_vmware_utility_installed)
  fi

  (echo >&2 "Available Providers:")
  if [ "$VBOX_PRESENT" == "1" ]; then
    (echo >&2 "${GOODTOGO} virtualbox")
  fi
  if [[ $VMWARE_FUSION_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_UTILITY_PRESENT -eq 1 ]]; then
    (echo >&2 "${GOODTOGO} vmware_desktop")
  fi
  if [[ $VMWARE_WORKSTATION_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_DESKTOP_PLUGIN_PRESENT -eq 1 ]] && [[ $VAGRANT_VMWARE_UTILITY_PRESENT -eq 1 ]]; then
    (echo >&2 "${GOODTOGO} vmware_desktop")
  fi
  if [[ $VBOX_PRESENT -eq 0 ]] && [[ $VMWARE_FUSION_PRESENT -eq 0 ]] && [[ $VMWARE_WORKSTATION -eq 0 ]]; then
    (echo >&2 "${ERROR} You need to install a provider such as VirtualBox or VMware Fusion/Workstation to build DetectionLab.")
    exit 1
  fi
  if [[ $VBOX_PRESENT -eq 1 ]] && [[ $VMWARE_FUSION_PRESENT -eq 1 || $VMWARE_WORKSTATION_PRESENT -eq 1 ]]; then
    (echo >&2  "${INFO} Both VMware Workstation/Fusion and Virtualbox appear to be installed on this system.")
    (echo >&2  "${INFO} Please consider setting the VAGRANT_DEFAULT_PROVIDER environment variable to prevent confusion." )
    (echo >&2  "${INFO} More details can be found here: https://www.vagrantup.com/docs/providers/default" )
    (echo >&2  "${INFO} Additionally, please ensure only one providers' network adapters are active at any given time." )
  fi
}

# Check to see if boxes exist in the "Boxes" directory already
check_boxes_built() {
  BOXES_BUILT=$(find "$VAGRANT_DIR"/../Boxes -name "*.box" | wc -l)
  if [ "$BOXES_BUILT" -gt 0 ]; then
    (echo >&2 "${INFO} WARNING: You seem to have at least one .box file present in the Boxes directory already.")
    (echo >&2 "${INFO} If you would like to use the pre-built boxes, please remove all files from the Boxes directory.")
    (echo >&2 "${INFO} See https://www.detectionlab.network/customization/buildpackerboxes/ for more information about this message")
  else
    (echo >&2 "${GOODTOGO} No custom built boxes found")
  fi
}

# Check to see if any Vagrant instances exist already
check_vagrant_instances_exist() {
  cd "$VAGRANT_DIR"|| exit 1
  # Vagrant status has the potential to return a non-zero error code, so we work around it with "|| true"
  VAGRANT_STATUS_OUTPUT=$(vagrant status)
  VAGRANT_BUILT=$(echo "$VAGRANT_STATUS_OUTPUT" | grep -c 'not created') || true
  if [ "$VAGRANT_BUILT" -ne 4 ]; then
    (echo >&2 "${INFO} You appear to have already created at least one Vagrant instance:")
    # shellcheck disable=SC2164
    cd "$VAGRANT_DIR" && echo "$VAGRANT_STATUS_OUTPUT" | grep -v 'not created' | grep -E 'logger|dc|wef|win10' 
    (echo >&2 "${INFO} If you want to start with a fresh install, you should run \`vagrant destroy -f\` to remove existing instances.")
  else 
    (echo >&2 "${GOODTOGO} No Vagrant instances have been created yet")
  fi
}

check_vagrant_reload_plugin() {
  # Ensure the vagrant-reload plugin is installed
  VAGRANT_RELOAD_PLUGIN_INSTALLED=$(vagrant plugin list | grep -c 'vagrant-reload')
  if [ "$VAGRANT_RELOAD_PLUGIN_INSTALLED" != "1" ]; then
    (echo >&2 "${ERROR} The vagrant-reload plugin is required and was not found. This script will attempt to install it now.")
    if ! $(which vagrant) plugin install "vagrant-reload"; then
      (echo >&2 "Unable to install the vagrant-reload plugin. Please try to do so manually and re-run this script.")
      exit 1
    else 
      (echo >&2 "${GOODTOGO} The vagrant-reload plugin was successfully installed!")
    fi
  else
    (echo >&2 "${GOODTOGO} The vagrant-reload plugin is currently installed")
  fi
}

# Check available disk space. Recommend 80GB free, warn if less.
check_disk_free_space() {
  FREE_DISK_SPACE=$(df -m "$HOME" | tr -s ' ' | grep '/' | cut -d ' ' -f 4)
  if [ "$FREE_DISK_SPACE" -lt 80000 ]; then
    (echo >&2 -e "Warning: You appear to have less than 80GB of HDD space free on your primary partition. If you are using a separate parition, you may ignore this warning.\n")
    (df >&2 -m "$HOME")
    (echo >&2 "")
  else
    (echo >&2 "${GOODTOGO} You have more than 80GB of free space on your primary partition")
  fi
}

main() {
  # Get location of prepare.sh
  # https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
  VAGRANT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (echo >&2 "[+] Checking for necessary tools in PATH...")
  check_packer_path
  check_vagrant_path
  check_curl_path
  (echo >&2 "")
  (echo >&2 "[+] Checking if any boxes have been manually built...")
  check_boxes_built
  (echo >&2 "")
  (echo >&2 "[+] Checking for disk free space...")
  check_disk_free_space
  (echo >&2 "")
  (echo >&2 "[+] Checking if any Vagrant instances have been created...")
  check_vagrant_instances_exist
  (echo >&2 "")
  (echo >&2 "[+] Checking if the vagrant-reload plugin is installed...")
  check_vagrant_reload_plugin
  (echo >&2 "")
  (echo >&2 "[+] Enumerating available providers...")
  list_providers

  (echo >&2 '')
  # shellcheck disable=SC2016
  (echo >&2 'To get started building DetectionLab, run `vagrant up`.')
  (echo >&2 'If you run into any issues along the way, check out the troubleshooting and known issues page: ')
  (echo >&2 'https://www.detectionlab.network/deployment/troubleshooting/')
}

main 
exit 0
