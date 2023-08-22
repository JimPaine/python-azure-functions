targetScope = 'resourceGroup'

@allowed(['dev', 'prod'])
param environment string = 'dev'
param location string = resourceGroup().location
param principalId string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource hub 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: 'hub${suffix}'
  location: location

  properties: {

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
    principalId: principalId
    roleDefinitionId: hubReader.id
  }
  scope: hub
}
