targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param storageName string

param insightsName string

param hubName string

param acrName string

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

resource acr 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' existing = {
  name: acrName
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

@description('This is the built-in Blob data owner role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource storageBlobOwner 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
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

@description('This is the built-in ACR Pull role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource acrPull 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
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

resource storageBlobOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, msi.id, 'storageBlobOwner')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: storageBlobOwner.id
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

resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, msi.id, 'pull')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: acrPull.id
    principalType: 'ServicePrincipal'
  }
  scope: acr
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

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storage
}

resource func 'Microsoft.Web/sites@2022-09-01' = {
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
    vnetRouteAllEnabled: true
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true

    siteConfig: {
      linuxFxVersion: 'Python|3.10'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: msi.properties.clientId
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Enabled'
      vnetRouteAllEnabled: true
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      healthCheckPath: '/api/health'
      appSettings: [
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storage.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__tenantId'
          value: msi.properties.tenantId
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: msi.properties.clientId
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
        {
          name: 'PYTHON_ENABLE_WORKER_EXTENSIONS'
          value: '1'
        }
      ]
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnosticSettings'
  properties: {
    workspaceId: insights.properties.WorkspaceResourceId
    metrics: [
      {
        category: 'AllMetrics'
        timeGrain: null
        enabled: true
      }
    ]
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
  }
  scope: func
}

output id string = func.id
output functionPrincipalId string = msi.properties.principalId
