targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

var suffix = uniqueString(subscription().id, resourceGroup().id)

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

output name string = namespace.name
output namespaceId string = namespace.id
