# Drop the storage account private endpoint and all the related resources
$rgName = Read-Host -Prompt "Name of the new resouce group"

$stg = Get-AzStorageAccount -ResourceGroupName $rgName | ? StorageAccountName -like 'demostg*'

Get-AzPrivateEndpoint | ? { $_.PrivateLinkServiceConnections[0].PrivateLinkServiceId -eq $stg.id} | Remove-AzPrivateEndpoint

$dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $rgName -Name "privatelink.blob.core.windows.net"
Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rgName -ZoneName $dnsZone.Name | Remove-AzPrivateDnsVirtualNetworkLink
$dnsZone | Remove-AzPrivateDnsZone

# Drop the entire resource group
Remove-AzResourceGroup -Name $rgName