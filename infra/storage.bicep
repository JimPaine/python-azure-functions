targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param publicNetworkAccess string = 'Disabled'

param allowMicrosoftTrustedServices bool = false

param prefix string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${prefix}${suffix}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    publicNetworkAccess: allowMicrosoftTrustedServices ? 'Enabled' : publicNetworkAccess
    networkAcls: !allowMicrosoftTrustedServices ? {} : {
      resourceAccessRules: []
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}

output id string = storage.id
output name string = storage.name
