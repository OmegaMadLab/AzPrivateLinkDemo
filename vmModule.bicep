param VmAdmin string
@secure()
param VmAdminPwd string
param vmPrefix string
param subnetId string
param location string = resourceGroup().location
 
resource dnsFw 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: '${vmPrefix}-VM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: '${vmPrefix}-VM'
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
        name: '${vmPrefix}-DISK0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  stg.properties.primaryEndpoints.blob
      }
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmPrefix}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource stg 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: toLower(take('${vmPrefix}stg${uniqueString(resourceGroup().id)}', 24))
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

output ipAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
