REM build and run script for
C:\Windows\System32\bash.exe -c "echo '%~dp0buildAndRun.ps1' | sed -e 's|\\\\|/|g' -e 's|^\([A-Za-z]\)\:/\(.*\)|/mnt/\L\1\E/\2|' | cd && pwsh ./buildAndRun.ps1"
