targetScope = 'resourceGroup'

param zones array

resource dnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = [for zone in zones: {
  name: zone
  location: 'global'
}]
