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

module storage 'storage.bicep' = {
  name: 'storage'
  scope: main_group
  params: {
    location: location
  }
}

module storage_endpoints 'privateEndpoint/main.bicep' = {
  name: 'storage-endpoints'
  scope: networking_group
  params: {
    location: location
    namePrefix: 'storage'
    serviceId: storage.outputs.id
    serviceType: 'storage'
    subnetId: networking.outputs.storageId
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
  }
}

module function_endpoints 'privateEndpoint/main.bicep' = {
  name: 'func-endpoints'
  scope: networking_group
  params: {
    location: location
    namePrefix: 'function'
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
    functionPrincipalId: func.outputs.functionPrincipalId
  }
}

module hub_endpoints 'privateEndpoint/main.bicep' = {
  name: 'hub-endpoints'
  scope: networking_group
  params: {
    location: location
    namePrefix: 'eventhub'
    serviceId: hub.outputs.namespaceId
    serviceType: 'eventhub'
    subnetId: networking.outputs.hubId
    vnetId: networking.outputs.vnetId
  }
}
