targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param worspaceName string

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

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: worspaceName
}

var categories = [
  'ApplicationMetricsLogs'
  'ArchiveLogs'
  'AutoScaleLogs'
  'CustomerManagedKeyUserLogs'
  'EventHubVNetConnectionEvent'
  'KafkaCoordinatorLogs'
  'KafkaUserErrorLogs'
  'OperationalLogs'
  'RuntimeAuditLogs'
]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnosticSettings'
  properties: {
    workspaceId: workspace.id
    metrics: [
      {
        category: 'AllMetrics'
        timeGrain: null
        enabled: true
      }
    ]
    logs: [for category in categories: {
        category: category
        enabled: true
      }]
  }
  scope: namespace
}

output name string = namespace.name
output namespaceId string = namespace.id
