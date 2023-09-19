targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource acr 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' = {
  name: 'acr${suffix}'
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    networkRuleBypassOptions: 'None'
    publicNetworkAccess: publicNetworkAccess
  }
}

output id string = acr.id
output name string = acr.name
