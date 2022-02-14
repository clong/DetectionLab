net stop tiledatamodelsvc
echo "Preparing for Sysprep"
c:\windows\system32\sysprep\sysprep.exe /generalize /mode:vm /oobe /unattend:E:\unattend.xml