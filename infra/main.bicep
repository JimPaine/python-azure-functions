targetScope = 'subscription'

param name string = deployment().name
param location string = deployment().location
@description('Disable public access to resources. When set to true, the deployment agent is required to have network level access to the environment.')
param disablePublicAccess bool = true

@description('The "Diagnostic Services Trusted Storage Access" Magic APP object ID')
param diagnosticServicesTrustedStorageAccessId string

@description('The Principal ID of the agent doing the deployment. This can be a managed')
param deploymentAgentPrincipalId string

@allowed(['User', 'ServicePrincipal'])
param deploymentAgentPrincipalType string = 'ServicePrincipal'

resource main_group 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: name
  location: location
}

resource networking_group 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${name}_networking'
  location: location
}

module networking 'networking.bicep' = {
  name: 'networking'
  scope: networking_group
  params: {
    location: networking_group.location
  }
}

// no private endpoints needed as this account is used
// by app insights and the magic app due to no msi
// support on app insights all access disabled by
// default and traffic is through backbone
module insights_storage 'storage.bicep' = {
  name: 'insights-storage'
  scope: main_group
  params: {
    prefix: 'insights'
    location: location
    allowMicrosoftTrustedServices: true
  }
}

module insights 'insights.bicep' = {
  scope: main_group
  name: 'insights'
  params: {
    diagnosticServicesTrustedStorageAccessId: diagnosticServicesTrustedStorageAccessId
    storageName: insights_storage.outputs.name
    location: location
  }
}

module insight_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'insight-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: insights.outputs.plsId
    serviceType: 'Microsoft.Insights/PrivateLinkScopes'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
    serviceName: insights.outputs.name
    serviceResourceGroupName: main_group.name
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  scope: main_group
  params: {
    prefix: 'func'
    location: location
    publicNetworkAccess: disablePublicAccess ? 'Disabled' : 'Enabled'
  }
}

module storage_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'storage-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: storage.outputs.id
    serviceType: 'Microsoft.Storage/storageAccounts'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
    serviceName: storage.outputs.name
    serviceResourceGroupName: main_group.name
  }
}

module storage_files 'storage.bicep' = {
  name: 'storage-files'
  scope: main_group
  params: {
    prefix: 'funcfiles'
    location: location
    publicNetworkAccess: disablePublicAccess ? 'Disabled' : 'Enabled'
    defaultToOAuthAuthentication: false // Azure function require that Azure Files are accessed via keys not AAD
  }
}

module storage_files_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'storage-files-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: storage_files.outputs.id
    serviceType: 'Microsoft.Storage/storageAccounts'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
    useExistingZones: true
    serviceName: storage_files.outputs.name
    serviceResourceGroupName: main_group.name
  }
  dependsOn: [
    storage_endpoints // use zones created here
  ]
}

module vault 'akv.bicep' = {
  name: 'vault'
  scope: main_group
  params: {
    location: location
    publicNetworkAccess: disablePublicAccess ? 'Disabled' : 'Enabled'
    deploymentAgentPrincipalId: deploymentAgentPrincipalId
    principalType : deploymentAgentPrincipalType
  }
}

module vault_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'vault-endpoints'
  scope: networking_group
  params: {
    serviceId: vault.outputs.id
    serviceName: vault.outputs.name
    serviceResourceGroupName: main_group.name
    serviceType: 'Microsoft.KeyVault/vaults'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
    location: location
  }
}

module func 'function.bicep' = {
  name: 'func'
  scope: main_group
  params: {
    egressSubnetId: networking.outputs.egressId
    location: location
    storageName: storage.outputs.name
    storageFilesName: storage_files.outputs.name
    insightsName: insights.outputs.name
    hubName: hub.outputs.name
    vaultName: vault.outputs.name
    publicNetworkAccess: disablePublicAccess ? 'Disabled' : 'Enabled'
  }
}

module function_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'func-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: func.outputs.id
    serviceType: 'Microsoft.Web/sites'
    subnetId: networking.outputs.ingressId
    vnetId: networking.outputs.vnetId
    serviceName: func.outputs.name
    serviceResourceGroupName: main_group.name
  }
}

module hub 'eventhub.bicep' = {
  name: 'hub'
  scope: main_group
  params: {
    location: location
    worspaceName: insights.outputs.workspaceName
  }
}

module hub_endpoints 'bicep-private-endpoints/main.bicep' = {
  name: 'hub-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: hub.outputs.namespaceId
    serviceType: 'Microsoft.EventHub/namespaces'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
    serviceName: hub.outputs.name
    serviceResourceGroupName: main_group.name
  }
}
