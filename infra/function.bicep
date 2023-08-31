targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param storageName string

param insightsName string

param hubName string

param egressSubnetId string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageName
}

resource insights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: insightsName
}

resource hub 'Microsoft.EventHub/namespaces@2022-10-01-preview' existing = {
  name: hubName
}

@description('This is the built-in Event Hub Data Receiver role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource hubReceiver 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
}

@description('This is the built-in Storage Key Operator role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource storageKeyOp 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '81a9662b-bebf-436f-a333-f67b29880f12'
}

@description('This is the built-in Blob data contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource storageBlobContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

@description('This is the built-in reader and data access role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource readerDataAccess 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'c12c1c16-33a1-487b-954d-41c89c60f349'
}

@description('This is the built-in Monitor Metric Publisher role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource metricPublisher 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'func${suffix}'
  location: location
}

resource storageKeyOpAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, msi.id, 'storageKeyOp')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: storageKeyOp.id
    principalType: 'ServicePrincipal'
  }
  scope: storage
}

resource storageBlobContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, msi.id, 'storageBlobContributor')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: storageBlobContributor.id
    principalType: 'ServicePrincipal'
  }
  scope: storage
}

resource readerDataAccessAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, msi.id, 'readerDataAccess')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: readerDataAccess.id
    principalType: 'ServicePrincipal'
  }
  scope: storage
}

resource insightsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(insights.id, msi.id, 'publisher')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: metricPublisher.id
    principalType: 'ServicePrincipal'
  }
  scope: insights
}

resource hubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(hub.id, msi.id, 'receiver')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: hubReceiver.id
    principalType: 'ServicePrincipal'
  }
  scope: hub
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
    reserved: true
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
    virtualNetworkSubnetId: egressSubnetId
    siteConfig: {
      linuxFxVersion: 'Python|3.10'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Enabled'
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
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'EventHubConnection__fullyQualifiedNamespace'
          value: replace(replace(replace(hub.properties.serviceBusEndpoint, 'https:', ''),'/',''),':443','')
        }
        {
          name: 'EventHubConnection__credential'
          value: 'managedidentity'
        }
        {
          name: 'EventHubConnection__clientId'
          value: msi.properties.clientId
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: insights.properties.ConnectionString
        }
      ]
    }
  }
}

output id string = func.id
output functionPrincipalId string = msi.properties.principalId
