targetScope = 'subscription'

param name string = deployment().name
param location string = deployment().location

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

module insight_storage 'storage.bicep' = {
  name: 'insight-storage'
  scope: main_group
  params: {
    prefix: 'insights'
    location: location
  }
}

module insight_storage_endpoints 'privateEndpoint/main.bicep' = {
  name: 'insight-storage-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: storage.outputs.id
    serviceType: 'storage'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}

module insights 'insights.bicep' = {
  scope: main_group
  name: 'insights'
  params: {
    location: location
    storageName: insight_storage.outputs.name
  }
}

module insight_endpoints 'privateEndpoint/main.bicep' = {
  name: 'insight-endpoints'
  scope: networking_group
  params: {
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
  }
}

module storage_endpoints 'privateEndpoint/main.bicep' = {
  name: 'storage-endpoints'
  scope: networking_group
  params: {
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
  }
}

module function_endpoints 'privateEndpoint/main.bicep' = {
  name: 'func-endpoints'
  scope: networking_group
  params: {
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
  }
}

module hub_endpoints 'privateEndpoint/main.bicep' = {
  name: 'hub-endpoints'
  scope: networking_group
  params: {
    location: location
    serviceId: hub.outputs.namespaceId
    serviceType: 'eventhub'
    subnetId: networking.outputs.endpoints
    vnetId: networking.outputs.vnetId
  }
}
