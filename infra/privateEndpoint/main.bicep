targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

param namePrefix string

param serviceId string

param vnetId string

param subnetId string

@allowed(['function', 'appservice', 'storage', 'eventhub'])
param serviceType string

var groupIds = serviceType == 'function' || serviceType == 'appservice' ? [ 'sites' ] : serviceType == 'storage' ? ['file', 'table', 'blob', 'queue'] : serviceType == 'eventhub' ? ['namespace'] : []

resource endpoints 'Microsoft.Network/privateEndpoints@2021-05-01' = [for groupId in groupIds: {
  name: '${namePrefix}-${groupId}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${namePrefix}-pe'
        properties: {
          privateLinkServiceId: serviceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}]

resource dnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = [for groupId in groupIds: {
  name: serviceType == 'function' || serviceType == 'appservice' ? 'privatelink.azurewebsites.net' : serviceType == 'storage' ? 'privatelink.${groupId}.${environment().suffixes.storage}' : serviceType == 'eventhub' ? 'privatelink.servicebus.windows.net' : ''
  location: 'global'
}]

resource storageDnsGoups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = [for (groupId, index) in groupIds: {
  name: '${namePrefix}-${groupId}-private-endpoint'
  parent: endpoints[index]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: dnsZones[index].id
        }
      }
    ]
  }
}]

resource storageNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [for (groupId, index) in groupIds: {
  name: dnsZones[index].name
  parent: dnsZones[index]
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}]
