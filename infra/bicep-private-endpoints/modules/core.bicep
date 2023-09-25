targetScope = 'resourceGroup'

@description('The location the resources will be deployed to.')
param location string = resourceGroup().location

@description('The resource ID of the vnet the private DNS zones will be attached to.')
param vnetId string

@description('The resource ID of the subnet that the endpoint will be deployed to.')
param subnetId string

@description('The resource ID of the service the endpoint is for.')
param serviceId string

@description('The name of the resource the endpoint is for.')
param serviceName string

@description('The group IDs required for the private endpoint.')
param groupIds array

@description('The zones required for the private endpoint.')
param zones array

param vnetLinkRequired bool

@batchSize(1)
resource endpoints 'Microsoft.Network/privateEndpoints@2021-05-01' = [for groupId in groupIds: {
  name: '${serviceName}-${groupId}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${serviceName}-pe'
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

resource existingDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' existing = [for zone in zones: {
  name: zone
}]

resource dnsGoups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = [for (groupId, index) in groupIds: {
  name: '${serviceName}-${groupId}-group'
  parent: endpoints[index]
  properties: {
    privateDnsZoneConfigs: [for (zone, i) in zones: {
      name: zone
      properties: {
        privateDnsZoneId: existingDnsZones[i].id
      }
    }]
  }
}]

resource networkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [for (zone, index) in zones: if(vnetLinkRequired) {
  name: '${zone}/${serviceName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
  dependsOn: existingDnsZones
}]
