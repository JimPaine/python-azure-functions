targetScope = 'resourceGroup'

@allowed(['dev', 'prod'])
@description('When set to prod it will removed public access to the storage account, so ensure that the build agent has network connectivity.')
param deploymentEnvironment string = 'prod'

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

module storage 'storage/main.bicep' = {
  name: 'storage'
  params: {
    storageSubnetCIDR: '10.0.2.0/24'
    vnetName: vnet.name
    location: location
    deploymentEnvironment: deploymentEnvironment
  }
}

module func 'function/main.bicep' = {
  name: 'func'
  params: {
    egressSubnetCIDR: '10.0.0.0/24'
    ingressSubnetCIDR: '10.0.1.0/24'
    vnetName: vnet.name
    location: location
    storageName: storage.outputs.name
  }
}


@description('This is the built-in Event Hub Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver')
resource hubReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource namespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: 'hub${suffix}'
  location: location

  properties: {

  }
}

resource x 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  name: 'demo'
  parent: namespace
}

resource readers 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(namespace.id, 'func', 'reader')
  properties: {
    principalId: func.outputs.principalId
    roleDefinitionId: hubReader.id
    principalType: 'ServicePrincipal'
  }
  scope: namespace
}
