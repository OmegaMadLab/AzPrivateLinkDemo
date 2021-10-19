Install-WindowsFeature -Name 'DNS' -IncludeAllSubFeature -IncludeManagementTools -Confirm:$false
Install-WindowsFeature -Name 'Web-Server' -Confirm:$false
ConvertTo-Html -Body 'Hello world' | Out-File 'C:\inetpub\wwwroot\default.htm' -Force
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled 'False' -Confirm:$false
Set-DnsServerForwarder -IPAddress '168.63.129.16' -confirm:$false
Restart-Computer -Force