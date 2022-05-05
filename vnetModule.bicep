param name string
param location string = resourceGroup().location
param addressPrefixes array
param subnets array
param dnsServers array = []

resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
    dhcpOptions: {
      dnsServers: dnsServers
    }
  }
}

output subnets array = vnet.properties.subnets
output vnetId string = vnet.id
