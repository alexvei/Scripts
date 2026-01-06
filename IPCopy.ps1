# This is a one liner to get the ipv4 in the clipboard. Just change the interfacealias name to what you want it

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ip=(Get-NetIPConfiguration -InterfaceAlias 'NAME' -ErrorAction Stop).IPv4Address.IPAddress; Set-Clipboard -Value $ip; Write-Host \"VPN IPv4 copied: $ip\"; Pause"
