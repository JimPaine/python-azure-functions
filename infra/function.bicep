targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param storageName string

param storageFilesName string

param insightsName string

param hubName string

param vaultName string

param egressSubnetId string

@allowed(['Enabled','Disabled'])
param publicNetworkAccess string = 'Disabled'

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageName
}

resource storageFiles 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageFilesName
}

resource insights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: insightsName
}

resource hub 'Microsoft.EventHub/namespaces@2022-10-01-preview' existing = {
  name: hubName
}

resource vault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: vaultName
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

@description('This is the built-in Secret User role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource secretReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
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

resource secretReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, msi.id, 'reader')
  properties: {
    principalId: msi.properties.principalId
    roleDefinitionId: secretReader.id
    principalType: 'ServicePrincipal'
  }
  scope: vault
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

resource filesConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'filesConnectionString'
  parent: vault
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageFiles.name};AccountKey=${storageFiles.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
  }
}

resource files 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: storageFiles
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: toLower('func${suffix}')
  parent: files
  properties: {
    accessTier: 'Hot'
    enabledProtocols: 'SMB'
  }
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
    keyVaultReferenceIdentity: msi.id
    publicNetworkAccess: publicNetworkAccess

    siteConfig: {
      linuxFxVersion: 'Python|3.10'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: '@Microsoft.KeyVault(SecretUri=${filesConnectionString.properties.secretUri})'
        }
        {
          name: 'WEBSITE_SKIP_CONTENTSHARE_VALIDATION'
          // https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references?tabs=azure-cli#considerations-for-azure-files-mounting
          value: '1' // skip validation when using key vault reference
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: share.name
        }
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
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
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
output name string = func.name
output functionPrincipalId string = msi.properties.principalId
