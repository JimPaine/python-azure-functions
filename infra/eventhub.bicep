targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param functionPrincipalId string

var suffix = uniqueString(subscription().id, resourceGroup().id)

@description('This is the built-in Event Hub Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver')
resource hubReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource namespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: 'hub${suffix}'
  location: location

  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource hub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  name: 'demo'
  parent: namespace
}

resource readers 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(namespace.id, 'func', 'reader')
  properties: {
    principalId: functionPrincipalId
    roleDefinitionId: hubReader.id
    principalType: 'ServicePrincipal'
  }
  scope: namespace
}

output namespaceId string = namespace.id
