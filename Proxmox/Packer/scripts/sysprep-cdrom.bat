net stop tiledatamodelsvc
echo "Preparing for sysprep"
c:\windows\system32\sysprep\sysprep.exe /generalize /mode:vm /oobe /unattend:E:\unattend.xml