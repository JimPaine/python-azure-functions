targetScope = 'resourceGroup'

@description('The location the resources will be deployed to.')
param location string = resourceGroup().location

@description('The resource ID of the vnet the private DNS zones will be attached to.')
param vnetId string

@description('The resource ID of the subnet that the endpoint will be deployed to.')
param subnetId string

@description('The name of the resource the endpoint is for.')
param serviceName string

@description('The resource ID of the service the endpoint is for.')
param serviceId string

@description('Use existing zones for this resource type.')
param useExistingZones bool = false

@description('The name of the resource group the service has been deployed to.')
param serviceResourceGroupName string = resourceGroup().name

@allowed([
  'Microsoft.AppConfiguration/configurationStores'
  'Microsoft.ContainerRegistry/registries'
  'Microsoft.ContainerService/managedClusters'
  'Microsoft.EventHub/namespaces'
  'Microsoft.Insights/PrivateLinkScopes'
  'Microsoft.KeyVault/vaults'
  'Microsoft.ServiceBus/namespaces'
  'Microsoft.SignalRService/signalR'
  'Microsoft.Storage/storageAccounts'
  'Microsoft.Web/sites'
  'Microsoft.Web/staticSites'
])
@description('The resource type of the service the endpoint is for.')
param serviceType string
module mapper 'modules/mapper.bicep' = {
  name: '${serviceName}-mapper'
  params: {
    serviceName: serviceName
    serviceType: serviceType
    serviceResourceGroupName: serviceResourceGroupName
  }
}

module zoneHandler 'modules/zoneHandler.bicep' = if(!useExistingZones) {
  name: '${serviceName}-zoneHandler'
  params: {
    zones: mapper.outputs.zones
  }
}

module core 'modules/core.bicep' = {
  name: '${serviceName}-core'
  params: {
    zones: mapper.outputs.zones
    groupIds: mapper.outputs.groupIds
    serviceName: serviceName
    serviceId: serviceId
    subnetId: subnetId
    vnetId: vnetId
    location: location
    vnetLinkRequired: !useExistingZones
  }
  dependsOn: !useExistingZones ? [zoneHandler] : []
}
