param nsgName string
param location string = resourceGroup().location
param ruleName string
param ruleDescription string = ruleName
param protocol string = 'Tcp'
param sourcePortRange string = '*'
param sourceAddressPrefix string = '*'
param destinationPortRange string = '*'
param destinationAddressPrefix string = '*'
@allowed([
  'Allow'
  'Deny'
])
param access string = 'Allow'
param priority int = 100
@allowed([
  'Inbound'
  'Outbound'
])
param direction string = 'Inbound'
param targetNicId string = ''

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: ruleName
        properties: {
          description: ruleDescription
          protocol: protocol
          sourcePortRange: sourcePortRange
          destinationPortRange: destinationPortRange
          sourceAddressPrefix: sourceAddressPrefix
          destinationAddressPrefix: targetNicId != '' ? reference(targetNicId,'2020-05-01', 'Full').properties.ipConfigurations[0].properties.privateIPAddress : destinationAddressPrefix
          access: access
          priority: priority
          direction: direction
        }
      }
    ]
  }
}
