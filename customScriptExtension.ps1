Install-WindowsFeature -Name 'DNS' -IncludeAllSubFeature -IncludeManagementTools;
Install-WindowsFeature -Name 'Web-Server';
Install-WindowsFeature -Name 'Web-FTP-Server' -IncludeAllSubFeature -IncludeManagementTools;
ConvertTo-Html -Body 'Hello world' | Out-File 'C:\inetpub\wwwroot\default.htm';
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled 'False';
Set-DnsServerForwarder -IPAddress '168.63.129.16';