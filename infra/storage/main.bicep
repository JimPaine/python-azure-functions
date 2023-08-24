targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

@description('The name of the vnet that any new subnets will be deployed to. Must be inside the same resource group.')
param vnetName string

@description('The IP block to deploy the storage tier to.')
param storageSubnetCIDR string

@allowed(['dev', 'prod'])
param deploymentEnvironment string = 'prod'

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'store${suffix}'
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
    publicNetworkAccess: 'Enabled'
  }
}

resource storageSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'storageSubnet'
  parent: vnet
  properties: {
    addressPrefix: storageSubnetCIDR
    privateEndpointNetworkPolicies: deploymentEnvironment == 'prod' ? 'Disabled' : 'Enabled'
  }
}

var storageEndpoints = [
  'file'
  'table'
  'blob'
  'queue'
]

resource storagePrivateEndpoints 'Microsoft.Network/privateEndpoints@2021-05-01' = [for endpoint in storageEndpoints: {
  name: 'storage-${endpoint}'
  location: location
  properties: {
    subnet: {
      id: storageSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-pe'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            endpoint
          ]
        }
      }
    ]
  }
}]

resource storageDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = [for endpoint in storageEndpoints: {
  name: 'privatelink.${endpoint}.${environment().suffixes.storage}'
  location: 'global'
}]

resource storageDnsGoups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = [for (endpoint, index) in storageEndpoints: {
  name: '${storage.name}-${endpoint}-private-endpoint'
  parent: storagePrivateEndpoints[index]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: storageDnsZones[index].id
        }
      }
    ]
  }
}]

resource storageNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [for (endpoint, index) in storageEndpoints: {
  name: 'privatelink.${endpoint}.${environment().suffixes.storage}-link'
  parent: storageDnsZones[index]
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}]

output name string = storage.name
