targetScope = 'resourceGroup'

param location string = resourceGroup().location

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
