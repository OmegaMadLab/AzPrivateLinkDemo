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
          useRemoteGateways: true
          remoteVirtualNetwork: {
            id: mainVnet.id
          }
        }
      }
    ]
    dhcpOptions: {
      dnsServers: [
        dnsFwNic.properties.ipConfigurations[0].properties.privateIPAddress
      ]
    }
  }
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: '${mainVnet.name}/main2ext'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: extVnet.id
    }
  }
}

// DNS forwarder VM
param VmAdmin string
@secure()
param VmAdminPwd string
var vmPrefix = 'DnsForwarder'

resource dnsFw 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: '${vmPrefix}-VM'
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'DnsForwarder'
      adminUsername: VmAdmin
      adminPassword: VmAdminPwd
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: 'name'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dnsFwNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  dnsFwStg.id
      }
    }
  }
}

resource dnsFwNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmPrefix}-NIC'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: mainVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource dnsFwStg 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: take('${vmPrefix}stg${uniqueString(resourceGroup().id)}', 25)
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
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
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

