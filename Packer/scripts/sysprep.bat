net stop tiledatamodelsvc
echo "I am shutting down"
c:\windows\system32\sysprep\sysprep.exe /generalize /mode:vm /oobe /unattend:a:\unattend.xml
shutdown /s
