targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

@description('The name of the vnet that any new subnets will be deployed to. Must be inside the same resource group.')
param vnetName string

@description('The IP block where the private endpoint will be deployed for inbound connections to the function.')
param ingressSubnetCIDR string

@description('The IP block that will be used to create a subnet for downstream consumption of private endpoints.')
param egressSubnetCIDR string

param storageName string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageName
}

@description('This is the built-in Event Hub Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource storageContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'func${suffix}'
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, msi.id, 'contributor')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: storageContributor.id
    principalType: 'ServicePrincipal'
  }
  scope: storage
}

resource ingress 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'ingress'
  parent: vnet
  properties: {
    addressPrefix: ingressSubnetCIDR
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource egress 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'egress'
  parent: vnet
  properties: {
    addressPrefix: egressSubnetCIDR
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverfarms'
        }
      }
    ]
  }
  dependsOn: [
    ingress // ensure subnets are created sequentially
  ]
}

resource farm 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'farm'
  location: location
  kind: 'linux'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    zoneRedundant: true
    targetWorkerCount: 3
    targetWorkerSizeId: 3
    maximumElasticWorkerCount: 20
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource func 'Microsoft.Web/sites@2020-12-01' = {
  name: 'func${suffix}'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${msi.id}' : {}
    }
  }
  properties: {
    serverFarmId: farm.id
    httpsOnly: true
    virtualNetworkSubnetId: egress.id
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Disabled'
      vnetRouteAllEnabled: true
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: storageConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(storage.name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET '
          value: '1'
        }
      ]
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'func-pe'
  location: location
  properties: {
    subnet: {
      id: ingress.id
    }
    privateLinkServiceConnections: [
      {
        name: 'func-pe'
        properties: {
          privateLinkServiceId: func.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource dnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output principalId string = msi.properties.principalId
