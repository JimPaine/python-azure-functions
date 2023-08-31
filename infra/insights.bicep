targetScope = 'resourceGroup'

param location string = resourceGroup().location

param storageName string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'workspace'
  location: location

  properties: {
    publicNetworkAccessForIngestion: 'Disabled'
    sku: {
      name: 'PerGB2018'
    }
  }
}

// resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
//   name: 'insights-msi-${suffix}'
//   location: location
// }

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'insights${suffix}'
  location: location
  kind: 'web'

  properties: {
    Application_Type: 'web'
    DisableLocalAuth: true
    Flow_Type: 'Bluefield'
    publicNetworkAccessForIngestion: 'Disabled'
    WorkspaceResourceId: workspace.id
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageName
}

resource storageLink 'microsoft.insights/components/linkedStorageAccounts@2020-03-01-preview' = {
  name: 'storageLink'
  parent: insights
  properties: {
    linkedStorageAccount: storage.id
  }
}

// @description('This is the built-in Blob data contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
// resource storageBlobContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
// }

// resource storageBlobContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(storage.id, msi.id, 'storageBlobContributor')
//   properties: {
//     principalId: msi.properties.principalId
//     roleDefinitionId: storageBlobContributor.id
//     principalType: 'ServicePrincipal'
//   }
//   scope: storage
// }

resource pls 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: 'pls'
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }

}

resource insights_scope 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: 'insights'
  parent: pls
  properties: {
    linkedResourceId: insights.id
  }
}

resource workspace_scope 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: 'workspace'
  parent: pls
  properties: {
    linkedResourceId: workspace.id
  }
}

output plsId string = pls.id
output name string = insights.name
