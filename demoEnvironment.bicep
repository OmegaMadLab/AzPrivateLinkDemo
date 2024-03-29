param location string = resourceGroup().location

// Vnets and peerings
resource mainVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'MainVnet'
  location: location
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
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/26'
        }
      }
      {
        name: 'vnetIntegration'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'vnetInt'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

var addressPrefixes = [
  '172.16.0.0/24'
]
var subnets = [
  {
    name: 'SubnetExt-1'
    properties: {
      addressPrefix: '172.16.0.0/24'
    }
  }
]

module extVnetModule 'vnetModule.bicep' = {
  name: 'ExternalVnet'
  params: {
    location: location
    addressPrefixes: addressPrefixes
    name: 'ExternalVnet'
    subnets: subnets 
  }
}

module extVnetWithDnsModule 'vnetModule.bicep' = {
  name: 'ExternalVnetUpdate'
  params: {
    location: location
    addressPrefixes: addressPrefixes
    name: 'ExternalVnet'
    subnets: subnets
    dnsServers: [
      extDcVmModule.outputs.ipAddress
    ]
  }
}

resource extVnet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: extVnetModule.name
}

resource peeringMain 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
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

resource peeringExt 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
  name: 'ext2main'
  parent: extVnet
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

param VmAdmin string
@secure()
param VmAdminPwd string

// DNS forwarder VM
module dnsFwVmModule 'vmModule.bicep' = {
  name: 'DnsForwarder-VM'
  params: {
    location: location
    subnetId: mainVnet.properties.subnets[0].id
    vmPrefix: 'DnsForwarder'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
    lbBePoolid: ilb.properties.backendAddressPools[0].id
  }
}

resource dnsFwVm 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  name: dnsFwVmModule.name
}

resource cse 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: dnsFwVm
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/OmegaMadLab/AzPrivateLinkDemo/main/customScriptExtension.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File CustomScriptExtension.ps1'
    }
  }
}

// ExtVnet DC VM
module extDcVmModule 'vmModule.bicep' = {
  name: 'ExternalDC-VM'
  params: {
    location: location
    subnetId: extVnetModule.outputs.subnets[0].id
    vmPrefix: 'ExternalDC'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
  }
}

resource extDcVm 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  name: extDcVmModule.name
}

var adCreateModulesURL = 'https://raw.githubusercontent.com/OmegaMadLab/LabTemplates/master/DSCResources/CreateADDC.ps1.zip'
var adCreateConfigurationFunction = 'CreateADDC.ps1\\CreateADDC'
var domainName = 'contoso.com'

resource extDcVm_dsc 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: extDcVm
  name: 'CreateADDC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.76'
    autoUpgradeMinorVersion: false
    settings: {
        modulesURL: adCreateModulesURL
        configurationFunction: adCreateConfigurationFunction
        properties: {
            domainName: domainName
            adminCreds: {
                userName: VmAdmin
                password: 'PrivateSettingsRef:adminPassword'
            }
        }
    }
    protectedSettings: {
        items: {
            adminPassword: VmAdminPwd
        }
    }
  }
}



// ExtVnet VM
module extVmModule 'vmModule.bicep' = {
  name: 'External-VM'
  params: {
    location: location
    subnetId: extVnetWithDnsModule.outputs.subnets[0].id
    vmPrefix: 'External'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
  }
}

resource extVm 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  name: extVmModule.name
}

var adJoinModulesURL = 'https://raw.githubusercontent.com/OmegaMadLab/LabTemplates/master/DSCResources/ADDomainJoin.ps1.zip'
var adJoinConfigurationFunction = 'ADDomainJoin.ps1\\ADDomainJoin'

resource extVm_dsc 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: extVm
  name: 'ADJoin'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.76'
    autoUpgradeMinorVersion: false
    settings: {
        modulesURL: adJoinModulesURL
        configurationFunction: adJoinConfigurationFunction
        properties: {
            domainName: domainName
            adminCreds: {
                userName: VmAdmin
                password: 'PrivateSettingsRef:adminPassword'
            }
        }
    }
    protectedSettings: {
        items: {
            adminPassword: VmAdminPwd
        }
    }
  }
}

// Bastion
resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: 'DemoBastion'
  location: location
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
  location: location
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
  location: location
  properties: {
    administratorLogin: VmAdmin
    administratorLoginPassword: VmAdminPwd
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2014-04-01' = {
  parent: sqlServer
  name: 'demoDB'
  location: location
  properties: {
    collation: 'Latin1_General_CI_AS'
    edition: 'Basic'
    maxSizeBytes: '104857600'
    requestedServiceObjectiveName: 'Basic'
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: toLower(take('demostg${uniqueString(resourceGroup().id)}', 24))
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

// Private endpoint and related resources for AzSQL
resource pEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'DemoSQL-PLINK'
  location: location
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

// FunctionApp
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'StdPlan'
  location: location
  sku: {
    name:'S1'
    capacity: 1
  }
}


resource azureFunction 'Microsoft.Web/sites@2020-12-01' = {
  name: 'demoFunctionApp-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: mainVnet.properties.subnets[3].id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageaccount.id, storageaccount.apiVersion).keys[0].value}'
        }        
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageaccount.id, storageaccount.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION' 
          value: '~7'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
    }
  }
}

resource codeSource 'Microsoft.Web/sites/sourcecontrols@2021-02-01' = {
  name: 'web'
  parent: azureFunction
  properties: {
    repoUrl: 'https://github.com/OmegaMadLab/SampleAzFunction'
    branch: 'main'
    isManualIntegration: true 
  }
}

// Private link service demo
resource customerVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'CustomerVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/23'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '192.168.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '192.168.1.0/26'
        }
      }
    ]
  }
}

module customerVmModule 'vmModule.bicep' = {
  name: 'Customer-VM'
  params: {
    location: location
    subnetId: customerVnet.properties.subnets[0].id
    vmPrefix: 'Customer'
    VmAdmin: VmAdmin
    VmAdminPwd: VmAdminPwd
  }
}

resource ilb 'Microsoft.Network/loadBalancers@2020-11-01' = {
  name: 'Demo-ILB'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: mainVnet.properties.subnets[0].id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendConfig'
      }
    ]
    loadBalancingRules: [
      {
        name: 'httpTraffic'
        properties: {
          frontendIPConfiguration: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'Demo-ILB')}/frontendIpConfigurations/frontendConfig'
          }
          backendAddressPool: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'Demo-ILB')}/backendAddressPools/backendConfig'
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'Demo-ILB')}/probes/probe'
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource pLinkSvc 'Microsoft.Network/privateLinkServices@2021-03-01' = {
  name: 'PLINKSVC-DEMO'
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: ilb.properties.frontendIPConfigurations[0].id
      }
    ]
    ipConfigurations: [
      {
        name: 'serviceProvider-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: mainVnet.properties.subnets[1].id
          }
          primary: false
        }
      }
    ]
  }
}

resource pEndpointCustomer 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'PLINK-EXTSVC'
  location: location
  properties: {
    subnet: {
      id: customerVnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: 'PLINK-EXTSVC'
        properties: {
          privateLinkServiceId: pLinkSvc.id
        }
      }
    ]
  }
}

resource customerBastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: 'DemoCustomerBastion'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    dnsName: take('azprivatelinkdemo-customer-${uniqueString(resourceGroup().id)}', 30)
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          publicIPAddress: {
            id: publicIPAddressCustomer.id
          }
          subnet: {
            id: customerVnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource publicIPAddressCustomer 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'DemoBastion-CustomerPIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NSG
module nsgIn 'simpleNsgModule.bicep' = {
  name: 'NSG-Inbound'
  params: {
    location: location
    nsgName: 'NSG-Inbound'
    ruleName: 'BlockSQL'
    ruleDescription: 'Block the connectivity to Az SQL via private endpoint on port 1433'
    targetNicId: pEndpoint.properties.networkInterfaces[0].id
    destinationPortRange: '1433'
    access: 'Deny'
    direction: 'Inbound'
  }
}

module nsgOut 'simpleNsgModule.bicep' = {
  name: 'NSG-Outbound'
  params: {
    location: location
    nsgName: 'NSG-Outbound'
    ruleName: 'BlockSQL'
    ruleDescription: 'Block the connectivity to Az SQL via private endpoint on port 1433'
    targetNicId: pEndpoint.properties.networkInterfaces[0].id
    destinationPortRange: '1433'
    access: 'Deny'
    direction: 'Outbound'
  }
}
