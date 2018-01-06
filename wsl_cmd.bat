REM run command in project folder using WSL
C:\Windows\System32\bash.exe -c "echo '%~dp0' | sed -e 's|\\\\|/|g' -e 's|^\([A-Za-z]\)\:/\(.*\)|/mnt/\L\1\E/\2|' | cd && pwsh %1"
