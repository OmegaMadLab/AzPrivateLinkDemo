// Vnets and peerings
resource mainVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'MainVnet'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'Subnet-2'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/26'
        }
      }
    ]
  }
}

resource extVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'ExternalVnet'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'SubnetExt-1'
        properties: {
          addressPrefix: '172.16.0.0/24'
        }
      }
    ]
    virtualNetworkPeerings: [
      {
        name: 'ext2main'
        properties: {
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: true
          allowGatewayTransit: true
          useRemoteGateways: false
          remoteVirtualNetwork: {
            id: mainVnet.id
          }
        }
      }
    ]
    dhcpOptions: {
      dnsServers: [
        dnsFwVm.outputs.ipAddress
      ]
    }
  }
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: 'main2ext'
  parent: mainVnet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: extVnet.id
    }
  }
}

param VmAdmin string
@secure()
param VmAdminPwd string

// DNS forwarder VM
module dnsFwVm 'vmModule.bicep' = {
  name: 'dnsFwVm'
  params: {
    subnetId: mainVnet.properties.subnets[0].id
    vmPrefix: 'DnsForwarder'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
  }
}

// ExtVnet VM
module extVm 'vmModule.bicep' = {
  name: 'extVm'
  params: {
    subnetId: extVnet.properties.subnets[0].id
    vmPrefix: 'External'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
  }
  
}

// Bastion
resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: 'DemoBastion'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    dnsName: take('azprivatelinkdemo-${uniqueString(resourceGroup().id)}', 30)
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: mainVnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'DemoBastion-PIP'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// PaaS resources
resource sqlServer 'Microsoft.Sql/servers@2014-04-01' ={
  name: take('demosql-${uniqueString(resourceGroup().id)}', 15)
  location: resourceGroup().location
  properties: {
    administratorLogin: VmAdmin
    administratorLoginPassword: VmAdminPwd
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2014-04-01' = {
  parent: sqlServer
  name: 'demoDB'
  location: resourceGroup().location
  properties: {
    collation: 'SQL_Latin1_CP1_CI_AS'
    edition: 'Basic'
    maxSizeBytes: '10000000'
    requestedServiceObjectiveName: 'Basic'
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: toLower(take('demostg${uniqueString(resourceGroup().id)}', 24))
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

// Private endpoint and related resources for AzSQL
resource pEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'DemoSQL-PLINK'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: mainVnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'DemoSQL-PLINK'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  } 
}

resource pDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

resource pDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${pDnsZone.name}/${pDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: mainVnet.id
    }
  }
}

resource pDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-03-01' = {
  name: '${pEndpoint.name}/MyDnsGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: pDnsZone.id
        }
      }
    ]
  }
}
