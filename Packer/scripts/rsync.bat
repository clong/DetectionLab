rem install rsync
if not exist "C:\Windows\Temp\7z920-x64.msi" (
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://www.7-zip.org/a/7z920-x64.msi', 'C:\Windows\Temp\7z920-x64.msi')" <NUL
)
msiexec /qb /i C:\Windows\Temp\7z920-x64.msi

pushd C:\Windows\Temp
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://mirrors.kernel.org/sourceware/cygwin/x86_64/release/rsync/rsync-3.1.0-1.tar.xz', 'C:\Windows\Temp\rsync-3.1.0-1.tar.xz')" <NUL
cmd /c ""C:\Program Files\7-Zip\7z.exe" x rsync-3.1.0-1.tar.xz"
cmd /c ""C:\Program Files\7-Zip\7z.exe" x rsync-3.1.0-1.tar"
copy /Y usr\bin\rsync.exe "C:\Program Files\OpenSSH\bin\rsync.exe"
rmdir /s /q usr
del rsync-3.1.0-1.tar
popd

msiexec /qb /x C:\Windows\Temp\7z920-x64.msi

rem make symlink for c:/vagrant share
mklink /D "C:\Program Files\OpenSSH\vagrant" "C:\vagrant"
