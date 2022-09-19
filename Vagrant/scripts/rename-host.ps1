# Purpose: Changes the hostname. Used to replace the cfg.vm.hostname directive which forces a restart

param ([String] $hostname)

Rename-Computer -NewName $hostname -Force 