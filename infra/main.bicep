targetScope = 'subscription'

param name string = deployment().name
param location string = deployment().location
@description('Disable public access to the storage account used by the function app. If disabled, ensure that deployment agent has network access to the storage account.')
param disableFunctionAppStoragePublicAccess bool = true

@description('The "Diagnostic Services Trusted Storage Access" Magic APP object ID')
param diagnosticServicesTrustedStorageAccessId string

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

module insight_endpoints 'privateEndpoint/main.bicep' = {
  name: 'insight-endpoints'
  scope: networking_group
  params: {
    prefix: 'insights'
    location: location
    serviceId: insights.outputs.plsId
    serviceType: 'insights'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  scope: main_group
  params: {
    prefix: 'func'
    location: location
    publicNetworkAccess: disableFunctionAppStoragePublicAccess ? 'Disabled' : 'Enabled'
  }
}

module storage_endpoints 'privateEndpoint/main.bicep' = {
  name: 'storage-endpoints'
  scope: networking_group
  params: {
    prefix: 'func'
    location: location
    serviceId: storage.outputs.id
    serviceType: 'storage'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}

module func 'function.bicep' = {
  name: 'func'
  scope: main_group
  params: {
    egressSubnetId: networking.outputs.egressId
    location: location
    storageName: storage.outputs.name
    insightsName: insights.outputs.name
    hubName: hub.outputs.name
    acrName: acr.outputs.name
  }
}

module function_endpoints 'privateEndpoint/main.bicep' = {
  name: 'func-endpoints'
  scope: networking_group
  params: {
    prefix: 'func'
    location: location
    serviceId: func.outputs.id
    serviceType: 'function'
    subnetId: networking.outputs.ingressId
    vnetId: networking.outputs.vnetId
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

module hub_endpoints 'privateEndpoint/main.bicep' = {
  name: 'hub-endpoints'
  scope: networking_group
  params: {
    prefix: 'hub'
    location: location
    serviceId: hub.outputs.namespaceId
    serviceType: 'eventhub'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}

module acr 'acr.bicep' = {
  name: 'acr'
  scope: main_group
  params: {
    location: location
    publicNetworkAccess: 'Enabled'
  }
}

module acr_endpoints 'privateEndpoint/main.bicep' = {
  name: 'acr-endpoints'
  scope: networking_group
  params: {
    prefix: 'acr'
    location: location
    serviceId: acr.outputs.id
    serviceType: 'acr'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}
