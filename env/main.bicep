targetScope = 'resourceGroup'

@allowed(['dev', 'prod'])
param environment string = 'prod'
param location string = resourceGroup().location

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource hub 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: 'hub${suffix}'
  location: location

  properties: {

  }
}

module func 'function/main.bicep' = {
  name: 'func'
  params: {
    egressSubnetCIDR: '10.0.0.0/24'
    ingressSubnetCIDR: '10.0.1.0/24'
    storageSubnetCIDR: '10.0.2.0/24'
    vnetName: vnet.name
    location: location
  }
}


@description('This is the built-in Event Hub Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver')
resource hubReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource readers 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(hub.id, 'reader')
  properties: {
    principalId: func.outputs.funcPrincipalId
    roleDefinitionId: hubReader.id
  }
  scope: hub
}
